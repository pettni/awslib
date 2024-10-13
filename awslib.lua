--@meta awslib
--- Lua library for submitting aws requests.
---
--- Implements procedure in
--- https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv-create-signed-request.html
---
---@class awslib
awslib = {}

local digest = require 'openssl.digest'
local hmac = require 'openssl.hmac'

local function hex_encode(str)
  return str:gsub('.', function(c) return ('%02x'):format(string.byte(c)) end)
end

local function sha256(str) return digest.new('sha256'):final(str) end

local function hmac_sha256(key, str) return hmac.new(key, 'sha256'):final(str) end

local function get_signature_key(key, date_stamp, region_name, service_name)
  local k_date = hmac_sha256('AWS4' .. key, date_stamp)
  local k_region = hmac_sha256(k_date, region_name)
  local k_service = hmac_sha256(k_region, service_name)
  local k_signing = hmac_sha256(k_service, 'aws4_request')
  return k_signing
end

local function create_canonical_request(method, uri, query_params, headers, hashed_payload)
  local canonical_uri = uri

  local canonical_querystring = ''
  if query_params then
    local sorted_params = {}
    for k, v in pairs(query_params) do
      table.insert(sorted_params, { k, v })
    end
    table.sort(sorted_params, function(a, b) return a[1] < b[1] end)
    for _, pair in ipairs(sorted_params) do
      if canonical_querystring ~= '' then canonical_querystring = canonical_querystring .. '&' end
      canonical_querystring = canonical_querystring .. pair[1] .. '=' .. pair[2]
    end
  end

  local sorted_headers = {}
  for k, v in pairs(headers) do
    table.insert(sorted_headers, { string.lower(k), v })
  end
  table.sort(sorted_headers, function(a, b) return a[1] < b[1] end)

  local canonical_headers = ''
  local signed_headers = ''
  for _, header in pairs(sorted_headers) do
    canonical_headers = canonical_headers .. header[1] .. ':' .. header[2] .. '\n'
    if signed_headers ~= '' then signed_headers = signed_headers .. ';' end
    signed_headers = signed_headers .. header[1]
  end

  local canonical_request = method
    .. '\n'
    .. canonical_uri
    .. '\n'
    .. canonical_querystring
    .. '\n'
    .. canonical_headers
    .. '\n'
    .. signed_headers
    .. '\n'
    .. hashed_payload

  return canonical_request, signed_headers, canonical_querystring
end

---
---Read aws access key and secret access key from file.
---
---Note: grabs the first profile; does not check that lines are adjacent.
---
---@param filename string
---@return string | nil, string | nil
---@nodiscard
function awslib.read_aws_credentials(filename)
  local access_key_id, secret_access_key

  local file = io.open(filename, 'r')
  if not file then
    print('Error: Unable to open file ' .. filename)
    return nil, nil
  end

  for line in file:lines() do
    local key, value = line:match '(%S+)%s*=%s*(%S+)'
    if key == 'aws_access_key_id' then
      access_key_id = value
    elseif key == 'aws_secret_access_key' then
      secret_access_key = value
    end
  end

  file:close()

  return access_key_id, secret_access_key
end

---
---Generate and sign an aws API call.
---
---@param params table
---@return table
---@nodiscard
function awslib.generate_request(params)
  local access_key = params.access_key
  local secret_key = params.secret_key
  local region = params.region
  local service = params.service
  local host = params.host
  local method = params.method or 'GET'
  local uri = params.uri or '/'
  local query_params = params.query_params
  local payload = params.body or ''

  local t = os.date '!*t'
  local amz_date = ('%04d%02d%02dT%02d%02d%02dZ'):format(t.year, t.month, t.day, t.hour, t.min, t.sec)
  local date = ('%04d%02d%02d'):format(t.year, t.month, t.day)

  local hashed_payload = hex_encode(sha256(payload or ''))

  local headers = {
    ['host'] = host,
    ['x-amz-content-sha256'] = hashed_payload,
    ['x-amz-date'] = amz_date,
  }
  for k, v in pairs(params.headers or {}) do
    headers[k] = v
  end

  local canonical_request, signed_headers, canonical_querystring =
    create_canonical_request(method, uri, query_params, headers, hashed_payload)

  local credential_scope = date .. '/' .. region .. '/' .. service .. '/aws4_request'

  local string_to_sign = 'AWS4-HMAC-SHA256'
    .. '\n'
    .. amz_date
    .. '\n'
    .. credential_scope
    .. '\n'
    .. hex_encode(sha256(canonical_request))

  local signing_key = get_signature_key(secret_key, date, region, service)
  local signature = hex_encode(hmac_sha256(signing_key, string_to_sign))

  headers['Authorization'] = ('AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s'):format(
    access_key,
    credential_scope,
    signed_headers,
    signature
  )

  local url = 'https://' .. host .. uri
  if query_params then url = url .. '?' .. canonical_querystring end

  return {
    url = url,
    method = method,
    headers = headers,
  }
end

return awslib
