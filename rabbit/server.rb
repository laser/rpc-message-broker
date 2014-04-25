#!/usr/bin/env ruby
require 'bunny'
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

conn = Bunny.new
conn.start
ch = conn.create_channel
q  = ch.queue('calc')
x  = ch.default_exchange

q.subscribe(block: true) do |delivery_info, properties, payload|
  req_message = JSON.parse payload

  # calculate a result
  result = calculator.send *(req_message['params'].unshift(req_message['method']))

  reply = {
    'id' => req_message['id'],
    'result' => result,
    'jsonrpc' => '2.0'
  }

  # enqueue our reply in the return queue
  x.publish(JSON.generate(reply), routing_key: properties.reply_to, correlation_id: properties.correlation_id)
end
