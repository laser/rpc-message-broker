#!/usr/bin/env ruby
require 'bunny'
require 'securerandom'
require 'json'

conn = Bunny.new
conn.start

ch = conn.create_channel
q  = ch.queue('calc', auto_delete: false)
x  = ch.default_exchange

# request id will be used as the name of the return queue
req_message = {
  'id' => SecureRandom.hex,
  'jsonrpc' => '2.0',
  'method' => 'add',
  'params' => [1, 5.1]
}

# send out our request, serialized as JSON
x.publish(JSON.generate(req_message), {
  routing_key: q.name,
  reply_to: req_message['id']
})

# we'll set this in the block passed to subscribe below
response = nil

# create a temporary return queue (idempotent operation)
reply_q = ch.queue(req_message['id'], auto_delete: true)

# subscribe to the return queue in a blocking fashion
reply_q.subscribe(block: true) do |delivery_info, properties, payload|
  response = payload            # visible via closure
  delivery_info.consumer.cancel # unblock the consumer
end

# print it out to the console
JSON.parse(response)['message']
puts "1+5.1=%.1f" % JSON.parse(response)['result'] # 1+5.1=6.1
