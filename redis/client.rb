#!/usr/bin/env ruby
require 'redis'
require 'securerandom'
require 'json'

redis_client = Redis.connect url: 'redis://localhost:6379'

# request id will be used as the name of the return queue
request = {
  'id' => SecureRandom.hex,
  'jsonrpc' => '2.0',
  'method' => 'add',
  'params' => [1, 5.1]
}

# insert our request at the head of the list
redis_client.lpush('calc', JSON.generate(request))

# pop last element off our list in a blocking fashion
channel, response = redis_client.brpop(request['id'], timeout=30)

# print it out to the console
JSON.parse(response)['message']
puts "1+5.1=%.1f" % JSON.parse(response)['result'] # 1+5.1=6.1
