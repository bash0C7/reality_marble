#!/usr/bin/env ruby
# Reality Marble: Basic Example
# This example demonstrates the simplest usage pattern.

require_relative "../lib/reality_marble"

puts "=" * 60
puts "Reality Marble: Basic Example"
puts "=" * 60

# Example 1: Simple mock with single return value
puts "\n1. Simple mock with return value:"
puts "-" * 40

RealityMarble.chant do
  expect(String, :upcase) { "MOCKED!" }
end.activate do
  result = "hello".upcase
  puts "  String#upcase('hello') => #{result.inspect}"
  puts "  ✓ Mock is active during activate block"
end

result_after = "hello".upcase
puts "  String#upcase('hello') => #{result_after.inspect} (outside activate)"
puts "  ✓ Original method restored after activate block"

# Example 2: Mock with conditional logic
puts "\n2. Mock with conditional block logic:"
puts "-" * 40

RealityMarble.chant do
  expect(Integer, :even?) do |num|
    puts "    [Mock] Checking if #{num} is even..."
    num.even?
  end
end.activate do
  puts "  5.even? => #{5.even?}"
  puts "  10.even? => #{10.even?}"
  puts "  ✓ Block logic was executed for each call"
end

# Example 3: Multiple expectations in one chant
puts "\n3. Multiple expectations:"
puts "-" * 40

marble = RealityMarble.chant do
  expect(Array, :length) { 999 }
  expect(Array, :first) { "mocked-first" }
end

marble.activate do
  arr = [1, 2, 3]
  puts "  [1, 2, 3].length => #{arr.length}"
  puts "  [1, 2, 3].first => #{arr.first.inspect}"
  puts "  ✓ Multiple mocks are active simultaneously"
end

# Example 4: Inspect call history
puts "\n4. Call history inspection:"
puts "-" * 40

marble = RealityMarble.chant do
  expect(Hash, :keys) { %w[key1 key2] }
end

marble.activate do
  h = { a: 1, b: 2 }
  h.keys
  h.keys
  puts "  Called h.keys twice"
end

calls = marble.calls_for(Hash, :keys)
puts "  Call history:"
puts "    - Total calls: #{calls.length}"
puts "    - Call 1 args: #{calls[0].args.inspect}"
puts "    - Call 2 args: #{calls[1].args.inspect}"
puts "  ✓ Call history is tracked automatically"

# Example 5: Exception raising mock
puts "\n5. Mock that raises exception:"
puts "-" * 40

RealityMarble.chant do
  expect(File, :read) do |path|
    raise Errno::ENOENT, "No such file: #{path}"
  end
end.activate do
  File.read("/nonexistent/file")
rescue Errno::ENOENT => e
  puts "  Caught exception: #{e.message}"
  puts "  ✓ Mock exception was raised as expected"
end

# Example 6: Using the simple mock helper
puts "\n6. Simple mock helper (no chant/activate boilerplate):"
puts "-" * 40

RealityMarble.mock(Enumerable, :empty?) { |_enum| false }
result = [].empty?
puts "  [].empty? => #{result.inspect}"
puts "  ✓ Mock helper activated immediately"

# NOTE: Remember to reset context in test teardown
RealityMarble::Context.reset_current
puts "  ✓ Context reset (cleanup)"

puts "\n#{"=" * 60}"
puts "All examples completed successfully!"
puts "=" * 60
