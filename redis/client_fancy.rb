#!/usr/bin/env ruby
require 'redis'
require 'securerandom'
require 'json'

# request id will be used as the name of the return queue

class RedisRpcClient

  def initialize(redis_url)
    @redis_client = Redis.connect url: redis_url
  end

  def method_missing(name, *args)
    request = {
      'id' => SecureRandom.hex,
      'jsonrpc' => '2.0',
      'method' => name,
      'params' => args
    }

    # insert our request at the head of the list
    @redis_client.lpush('calc', JSON.generate(request))

    # pop last element off our list in a blocking fashion
    channel, response = @redis_client.brpop(request['id'], timeout=30)

    parsed = JSON.parse(response)
    parsed['result']
  end

end

# create the client and connect to Redis
client = RedisRpcClient.new 'redis://localhost:6379'

# remote a call to 'add'
sum = client.add 1, 5.1

# print it out to the console
puts "1+5.1=%.1f" % sum # 1+5.1=6.1
