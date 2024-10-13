local digest = require("openssl.digest")
local hmac = require("openssl.hmac")
local http = require("socket.http")
local ltn12 = require("ltn12")

local function hex_encode(str)
	return (str:gsub(".", function(c)
		return string.format("%02x", string.byte(c))
	end))
end

local function hmac_sha256(key, msg)
	return hmac.new(key, "sha256"):final(msg)
end

local function get_signature_key(key, date_stamp, region_name, service_name)
	local k_date = hmac_sha256("AWS4" .. key, date_stamp)
	local k_region = hmac_sha256(k_date, region_name)
	local k_service = hmac_sha256(k_region, service_name)
	local k_signing = hmac_sha256(k_service, "aws4_request")
	return k_signing
end

local function read_aws_credentials(filename)
	local access_key_id, secret_access_key

	local file = io.open(filename, "r")
	if not file then
		print("Error: Unable to open file " .. filename)
		return nil, nil
	end

	for line in file:lines() do
		local key, value = line:match("(%S+)%s*=%s*(%S+)")
		if key == "aws_access_key_id" then
			access_key_id = value
		elseif key == "aws_secret_access_key" then
			secret_access_key = value
		end
	end

	file:close()

	return access_key_id, secret_access_key
end

local function string_strip(str)
	return str:gsub("^%s*(.-)%s*$", "%1")
end

local access_key, secret_key = read_aws_credentials("/home/petter/.aws/credentials")
local region = "us-east-1"

local date_table = os.date("!*t")
local x_amz_date = string.format(
	"%04d%02d%02dT%02d%02d%02dZ",
	date_table.year,
	date_table.month,
	date_table.day,
	date_table.hour,
	date_table.min,
	date_table.sec
)
local current_date = string.format("%04d%02d%02d", date_table.year, date_table.month, date_table.day)

local canonical_request = string.format(
	string_strip([[
GET
/

host:s3.amazonaws.com
x-amz-content-sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
x-amz-date:%s

host;x-amz-content-sha256;x-amz-date
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
]]),
	x_amz_date
)

local credential_scope = current_date .. "/" .. region .. "/s3/aws4_request"

local string_to_sign = string.format(
	string_strip([[
AWS4-HMAC-SHA256
%s
%s
%s
]]),
	x_amz_date,
	credential_scope,
	hex_encode(digest.new("sha256"):final(canonical_request))
)

local signing_key = get_signature_key(secret_key, current_date, region, "s3")
local signature = hex_encode(hmac_sha256(signing_key, string_to_sign))

local autorization_header = string.format(
	"AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=%s",
	access_key,
	credential_scope,
	signature
)

local response_body = {}
local _, code, _ = http.request({
	url = "http://s3.amazonaws.com",
	method = "GET",
	headers = {
		["X-Amz-Date"] = x_amz_date,
		["X-Amz-Content-Sha256"] = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
		["Authorization"] = autorization_header,
	},
	sink = ltn12.sink.table(response_body),
})

if code ~= 200 then
	print("Error: " .. code)
else
	print(table.concat(response_body))
end
