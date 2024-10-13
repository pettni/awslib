local awslib = require 'awslib'

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

local access_key, secret_key = awslib.read_aws_credentials '/home/petter/.aws/credentials'

-- s3 list buckets
local code, response = generate_and_submit_request {
  access_key = access_key,
  secret_key = secret_key,
  region = 'us-east-1',
  service = 's3',
  host = 's3.amazonaws.com',
  method = 'GET',
  uri = '/',
}

if code == 200 then
  print 's3 list succeeded'
  print(response)
else
  print 's3 list failed'
end

-- s3 put
code, response = generate_and_submit_request {
  access_key = access_key,
  secret_key = secret_key,
  region = 'us-east-1',
  service = 's3',
  host = 'pettni-devel.s3.amazonaws.com',
  method = 'PUT',
  uri = '/my_new_file',
  headers = {
    ['Content-Type'] = 'test/x-lua',
    ['x-amz-server-side-encryption'] = 'AES256',
    ['x-amz-storage-class'] = 'STANDARD',
  },
  body = 'hello world',
}

if code == 200 then
  print 's3 put succeeded'
  print(response)
else
  print 's3 put failed'
  print(response)
end

-- s3 list
code, response = generate_and_submit_request {
  access_key = access_key,
  secret_key = secret_key,
  region = 'us-east-1',
  service = 's3',
  host = 'pettni-devel.s3.amazonaws.com',
  method = 'GET',
  uri = '/',
  query_params = {
    ['list-type'] = 2,
    ['max-keys'] = 10,
  },
  headers = {
    ['x-amz-expected-bucket-owner'] = '863518411569',
  },
  body = '',
}

if code == 200 then
  print 's3 list files succeeded'
  print(response)
else
  print 's3 list files failed'
  print(response)
end

-- s3 delete
code, response = generate_and_submit_request {
  access_key = access_key,
  secret_key = secret_key,
  region = 'us-east-1',
  service = 's3',
  host = 'pettni-devel.s3.amazonaws.com',
  method = 'DELETE',
  uri = '/my_new_file',
}

if code == 204 then
  print 's3 delete succeeded'
  print(response)
else
  print 's3 delete failed'
  print(response)
end
