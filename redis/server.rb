#!/usr/bin/env ruby
require 'redis'
require 'json'

class Calculator

  def add(a, b)
    return a+b
  end

  def subtract(a, b)
    return a-b
  end

end

calculator = Calculator.new

redis_client = ::Redis.connect url: 'redis://localhost:6379'

while true
  # pop last element off our list in a blocking fashion
  channel, request = redis_client.brpop('calc')

  req_message = JSON.parse request

  result = calculator.send *(req_message['params'].unshift(req_message['method']))

  reply = JSON.generate({
    'id' => req_message['id'],
    'result' => result,
    'jsonrpc' => '2.0'
  })

  # 'respond' by inserting our reply at the tail of a 'reply'-list
  redis_client.rpush(req_message['reply_to'], reply)

  # set an expire value to make sure we don't leak
  redis_client.expire(req_message['reply_to'], 30)
end
