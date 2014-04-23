#!/usr/bin/env ruby
require 'sinatra'

class Calculator

  def add(a, b)
    return a+b
  end

  def subtract(a, b)
    return a-b
  end

end

calculator = Calculator.new

post '/calc' do
  req_message = JSON.parse request.body.read

  result = calculator.send *(req_message['params'].unshift(req_message['method']))

  status 200
  headers 'Content-Type' => 'application/json'

  JSON.generate({
    'id' => req_message['id'],
    'result' => result,
    'jsonrpc' => '2.0'
  })
end
