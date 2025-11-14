#!/usr/bin/env ruby
# Reality Marble: HTTP Client Example
# Demonstrates mocking HTTP requests without making real network calls.

require_relative '../lib/reality_marble'
require 'json'

puts "=" * 60
puts "Reality Marble: HTTP Client Example"
puts "=" * 60

# Example 1: Mock a simple GET request
puts "\n1. Mock HTTP GET request:"
puts "-" * 40

RealityMarble.chant do
  expect(Net::HTTP, :get_response) do |uri|
    # Simulate a successful response
    response = Net::HTTPSuccess.new('1.1', '200', 'OK')
    response.body = '{"id":1,"name":"Alice","email":"alice@example.com"}'
    response
  end
end.activate do
  uri = URI('http://api.example.com/users/1')
  response = Net::HTTP.get_response(uri)

  puts "  Status: #{response.code}"
  user = JSON.parse(response.body)
  puts "  User: #{user['name']} <#{user['email']}>"
  puts "  ✓ Successfully mocked HTTP response"
end

# Example 2: Mock different responses based on URL
puts "\n2. Different responses for different endpoints:"
puts "-" * 40

RealityMarble.chant do
  expect(Net::HTTP, :get_response) do |uri|
    case uri.path
    when '/api/users'
      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      response.body = '[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}]'
      response
    when '/api/users/1'
      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      response.body = '{"id":1,"name":"Alice"}'
      response
    when '/api/notfound'
      Net::HTTPNotFound.new('1.1', '404', 'Not Found')
    end
  end
end.activate do
  # Fetch user list
  list_response = Net::HTTP.get_response(URI('http://api.example.com/api/users'))
  users = JSON.parse(list_response.body)
  puts "  GET /api/users => #{list_response.code}"
  puts "    Returned #{users.length} users"

  # Fetch specific user
  user_response = Net::HTTP.get_response(URI('http://api.example.com/api/users/1'))
  user = JSON.parse(user_response.body)
  puts "  GET /api/users/1 => #{user_response.code}"
  puts "    User: #{user['name']}"

  # Try nonexistent endpoint
  not_found = Net::HTTP.get_response(URI('http://api.example.com/api/notfound'))
  puts "  GET /api/notfound => #{not_found.code}"

  puts "  ✓ Routed responses based on URI path"
end

# Example 3: Mock POST request with parameters
puts "\n3. Mock POST request with parameter handling:"
puts "-" * 40

request_bodies = []

RealityMarble.chant do
  expect(Net::HTTP, :request) do |http, request|
    # Capture the request body
    request_bodies << request.body

    # Simulate response based on method and path
    case request.path
    when '/api/users'
      if request.method == 'POST'
        response = Net::HTTPCreated.new('1.1', '201', 'Created')
        response.body = '{"id":3,"name":"Charlie"}'
        response
      end
    end
  end
end.activate do
  uri = URI('http://api.example.com/api/users')
  request = Net::HTTP::Post.new(uri.path)
  request.body = JSON.generate({name: 'Charlie', email: 'charlie@example.com'})
  request['Content-Type'] = 'application/json'

  http = Net::HTTP.new(uri.host)
  response = http.request(request)

  puts "  POST /api/users => #{response.code}"
  created_user = JSON.parse(response.body)
  puts "    Created user: #{created_user['name']}"
  puts "  ✓ POST request mocked with body capture"
end

# Verify the captured request body
puts "\n  Captured request body:"
puts "    #{JSON.parse(request_bodies[0])}"

# Example 4: Mock request failure and retry logic
puts "\n4. Mock request failure with retry simulation:"
puts "-" * 40

attempt_count = 0

RealityMarble.chant do
  expect(Net::HTTP, :get_response) do |uri|
    attempt_count += 1

    # Simulate: fail twice, succeed on third attempt
    if attempt_count < 3
      puts "    [Attempt #{attempt_count}] Simulating timeout..."
      raise Timeout::Error, "Connection timed out"
    else
      puts "    [Attempt #{attempt_count}] Success!"
      response = Net::HTTPSuccess.new('1.1', '200', 'OK')
      response.body = '{"status":"success"}'
      response
    end
  end
end.activate do
  uri = URI('http://api.example.com/api/data')

  # Simulate retry logic
  max_retries = 3
  attempt = 0

  begin
    attempt += 1
    response = Net::HTTP.get_response(uri)
  rescue Timeout::Error => e
    if attempt < max_retries
      puts "    Retrying (attempt #{attempt}/#{max_retries})..."
      retry
    else
      raise
    end
  end

  data = JSON.parse(response.body)
  puts "  ✓ Request succeeded after #{attempt} attempts"
  puts "    Response: #{data}"
end

# Example 5: Track all HTTP calls for audit
puts "\n5. Track and audit all HTTP calls:"
puts "-" * 40

marble = RealityMarble.chant do
  expect(Net::HTTP, :get_response) do |uri|
    response = Net::HTTPSuccess.new('1.1', '200', 'OK')
    response.body = '{"data":"mocked"}'
    response
  end
end

marble.activate do
  puts "  Making multiple HTTP calls..."

  uris = [
    'http://api.example.com/users',
    'http://api.example.com/posts',
    'http://api.example.com/comments'
  ]

  uris.each do |uri|
    Net::HTTP.get_response(URI(uri))
    puts "    GET #{uri}"
  end
end

# Audit the calls
calls = marble.calls_for(Net::HTTP, :get_response)
puts "  HTTP call audit:"
puts "    - Total calls: #{calls.length}"
puts "    - Endpoints:"
calls.each_with_index do |call, i|
  uri_obj = call.args[0]
  puts "      #{i + 1}. #{uri_obj.host}#{uri_obj.path}"
end

puts "  ✓ All HTTP calls tracked for audit/debugging"

# Cleanup
RealityMarble::Context.reset_current

puts "\n" + "=" * 60
puts "HTTP client examples completed!"
puts "=" * 60
