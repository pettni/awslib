local awslib = require 'awslib'

local access_key, secret_key = awslib.read_aws_credentials '/home/petter/.aws/credentials'

local function create_curl_cmd(params)
  local request = awslib.generate_request(params)
  local curl_cmd = ('%s'):format(request.method)
  for k, v in pairs(request.headers) do
    curl_cmd = curl_cmd .. ' -H "' .. k .. ':' .. v .. '"'
  end
  curl_cmd = curl_cmd .. ' ' .. request.url
  return curl_cmd
end

-- s3 list buckets
local curl_cmd = create_curl_cmd {
  access_key = access_key,
  secret_key = secret_key,
  region = 'us-east-1',
  service = 's3',
  host = 'pettni-devel.s3.amazonaws.com',
  method = 'GET',
  uri = '/',
}

print(curl_cmd)
