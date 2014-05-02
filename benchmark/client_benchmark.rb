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
x = ch.default_exchange
q = ch.queue('calc')
results = Hash.new { |h,k| h[k] = Queue.new }
reply_q2 = ch.queue('', exclusive: true)
reply_q2.subscribe(block: false) do |delivery_info, properties, payload|
  results[properties[:correlation_id]].push payload
end

n = 1000

Benchmark.bmbm do |b|
  b.report("RabbitMQ") do
    n.times do
      # request id will be used as the name of the return queue
      req_message = {
        'id' => SecureRandom.hex,
        'jsonrpc' => '2.0',
        'method' => 'add',
        'params' => [1, 5.1]
      }

      # send out our request, serialized as JSON
      x.publish(req_message.to_json, {
        correlation_id: req_message['id'],
        reply_to: reply_q2.name,
        routing_key: q.name
      })
      response = results[req_message['id']].pop
      results.delete req_message['id'] # prevent memory leak
      # subscribe to the return queue in a blocking fashion
      "1+5.1=%.1f" % JSON.parse(response)['result'] # 1+5.1=6.1
    end
  end

  b.report("Redis") do
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

  b.report("HTTP") do
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
