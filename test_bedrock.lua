local awslib = require 'awslib'

local access_key, secret_key = awslib.read_aws_credentials '/home/petter/.aws/credentials'

local function generate_and_submit_request(params)
  local http = require 'socket.http'
  local ltn12 = require 'ltn12'

  local request = awslib.generate_request(params)

  local response_body = {}

  request['sink'] = ltn12.sink.table(response_body)

  if params.body ~= nil and params.body ~= '' then
    request['headers']['Content-Length'] = string.len(params.body)
    request['source'] = ltn12.source.string(params.body)
  end

  local _, code, response_headers = http.request(request)

  return code, table.concat(response_body), response_headers
end

--- TODOS
--- json -> base64
--- implement streaming response reading in avante

local code, result = generate_and_submit_request {
  access_key = access_key,
  secret_key = secret_key,
  region = 'us-east-1',
  service = 'bedrock',
  host = 'bedrock-runtime.us-east-1.amazonaws.com',
  method = 'POST',
  uri = '/model/anthropic.claude-v2:1/invoke',
  headers = {
    ['Content-Type'] = 'application/json',
  },
  body = 'Hello world',
}

print(code)
print(result)
