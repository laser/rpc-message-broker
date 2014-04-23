#!/usr/bin/env ruby
require 'net/http'
require 'securerandom'
require 'json'

uri = URI('http://localhost:4567/calc')
req = Net::HTTP::Post.new uri.path
req.body = {
  'id' => SecureRandom.hex,
  'jsonrpc' => '2.0',
  'method' => 'add',
  'params' => [1, 5.1]
}.to_json

res = Net::HTTP.start(uri.hostname, uri.port) do |http|
  http.request(req)
end

puts "1+5.1=%.1f" % JSON.parse(res.body)['result'] # 1+5.1=6.1
