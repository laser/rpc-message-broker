#!/usr/bin/env ruby
require 'net/http'
require 'securerandom'
require 'json'
require 'benchmark'
require 'redis'
require 'bunny'
require 'pry'

uri = URI('http://localhost:4567/calc')

redis_client = Redis.connect url: 'redis://localhost:6379'
reply_q1 = SecureRandom.hex

conn = Bunny.new
conn.start
ch = conn.create_channel
q  = ch.queue('calc')
x  = ch.default_exchange
reply_q2 = ch.queue('', exclusive: true)

n = 1000

Benchmark.bmbm do |x|
  x.report("RabbitMQ") do
    n.times do
      x  = ch.default_exchange
      # request id will be used as the name of the return queue
      req_message = {
        'id' => SecureRandom.hex,
        'jsonrpc' => '2.0',
        'method' => 'add',
        'params' => [1, 5.1]
      }

      # we'll set this in the block passed to subscribe below
      response = nil

      # send out our request, serialized as JSON
      x.publish(JSON.generate(req_message), {
        correlation_id: req_message['id'],
        reply_to: reply_q2.name,
        routing_key: q.name
      })

      # subscribe to the return queue in a blocking fashion
      reply_q2.subscribe(block: true) do |delivery_info, properties, payload|
        if properties[:correlation_id] == req_message['id']
          response = payload            # visible via closure
          delivery_info.consumer.cancel # unblock the consumer
        end
      end

      y = "1+5.1=%.1f" % JSON.parse(response)['result'] # 1+5.1=6.1
    end
  end

  x.report("Redis") do
    n.times do
      req = {
        'id' => SecureRandom.hex,
        'jsonrpc' => '2.0',
        'method' => 'add',
        'params' => [1, 5.1],
        'reply_to' => reply_q1
      }.to_json
      redis_client.lpush('calc', req)
      channel, response = redis_client.brpop(reply_q1, timeout=30)
      y = "1+5.1=%.1f" % JSON.parse(response)['result'] # 1+5.1=6.1
    end
  end

  x.report("HTTP") do
    n.times do
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

      y = "1+5.1=%.1f" % JSON.parse(res.body)['result'] # 1+5.1=6.1
    end
  end
end
