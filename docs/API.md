# Reality Marble API Reference

## Module Methods

### RealityMarble.chant(&block)

Create a new Reality Marble and define expectations.

**Parameters:**
- `block` (optional): Block to execute in the context of a new Marble instance

**Returns:**
- `Marble` instance

**Example:**
```ruby
marble = RealityMarble.chant do
  expect(File, :exist?) { |path| path == '/tmp/test' }
  expect(File, :read) { |path| "mock content" }
end
```

---

### RealityMarble.mock(target_class, method_name, &block)

Convenience helper for simple inline mocking (no chant/activate boilerplate).

Activates immediately; deactivate via `Context.reset_current` (usually in teardown).

**Parameters:**
- `target_class` [Class, Module]: Class to mock
- `method_name` [Symbol]: Method name to mock
- `block`: Mock implementation (optional)

**Returns:**
- `Marble` instance (for call history inspection if needed)

**Example:**
```ruby
RealityMarble.mock(File, :exist?) { |path| path == '/tmp/test' }
assert File.exist?('/tmp/test')
```

---

## Marble Class

### marble.expect(target_class, method_name, &block)

Define an expectation for a method.

**Parameters:**
- `target_class` [Class, Module]: Class/module to mock
- `method_name` [Symbol]: Method name to mock
- `block`: Optional mock implementation (receives method arguments)

**Returns:**
- `Expectation` instance (for chaining DSL methods)

**Example:**
```ruby
marble = RealityMarble.chant do
  expect(File, :exist?) { |path| path == '/tmp/test' }
end
```

---

### marble.calls_for(target_class, method_name)

Get all recorded calls to a mocked method.

**Parameters:**
- `target_class` [Class, Module]: Class to look up
- `method_name` [Symbol]: Method name

**Returns:**
- `Array<CallRecord>` - List of all calls (empty if not mocked or not called)

**Example:**
```ruby
marble = RealityMarble.chant do
  expect(Logger, :info) { nil }
end.activate do
  Logger.info("message1")
  Logger.info("message2")
end

calls = marble.calls_for(Logger, :info)
assert_equal 2, calls.length
assert_equal "message1", calls[0].args[0]
assert_equal "message2", calls[1].args[0]
```

---

### marble.activate(&block)

Activate the Reality Marble for the duration of the block.

During activation:
- All expectations become active
- Original methods are backed up (if first marble)
- Mock methods are installed
- Test code executes

After the block:
- Mocks are removed
- Original methods are restored (if last marble)
- call_history is preserved

**Parameters:**
- `block`: Test code to execute

**Returns:**
- Result of the test block

**Example:**
```ruby
result = marble.activate do
  File.exist?('/tmp/test')  # Calls mock
end
assert_equal true, result
```

---

## Expectation Class

### expectation.with(*args)

Match against specific arguments.

**Parameters:**
- `args`: Arguments to match exactly

**Returns:**
- self (for method chaining)

**Example:**
```ruby
expect(Foo, :bar)
  .with(1, 2)
  .returns(3)
```

---

### expectation.with_any

Match against any arguments.

**Returns:**
- self (for method chaining)

**Example:**
```ruby
expect(Logger, :info)
  .with_any
  .returns(nil)
```

---

### expectation.returns(*values)

Set return value(s) for this expectation.

**Parameters:**
- `values`: Single value or sequence of values
  - Single value: always returns that value
  - Multiple values: returns values in sequence (cycles if exhausted)

**Returns:**
- self (for method chaining)

**Example:**
```ruby
# Single value
expect(File, :exist?)
  .with('/tmp/test')
  .returns(true)

# Sequence
expect(Counter, :next)
  .with_any
  .returns(1, 2, 3, 1, 2, 3, ...)  # Cycles
```

---

### expectation.raises(exception_class, message = nil)

Raise an exception when expectation is matched.

**Parameters:**
- `exception_class` [Class]: Exception class to raise
- `message` [String, optional]: Exception message

**Returns:**
- self (for method chaining)

**Example:**
```ruby
expect(Database, :connect)
  .with_any
  .raises(ConnectionError, "Connection refused")
```

---

### expectation.matches?(args)

Check if given arguments match this expectation's matchers.

(Usually called internally by Reality Marble framework)

**Parameters:**
- `args` [Array]: Arguments to test

**Returns:**
- Boolean

**Example:**
```ruby
exp = expect(Foo, :bar).with(1, 2)
assert exp.matches?([1, 2])
refute exp.matches?([2, 3])
```

---

## CallRecord Class

Represents a single method call in call_history.

### call_record.args

Array of positional arguments passed to the method.

**Returns:**
- Array

**Example:**
```ruby
calls = marble.calls_for(Logger, :info)
puts calls[0].args[0]  # First argument to first call
```

---

### call_record.kwargs

Hash of keyword arguments passed to the method.

**Returns:**
- Hash

**Example:**
```ruby
calls = marble.calls_for(API, :fetch)
puts calls[0].kwargs[:timeout]  # Keyword argument value
```

---

## Context Class

Thread-local execution context. Usually not called directly by users.

### Context.current

Get the current thread's Context instance (creates if needed).

**Returns:**
- `Context` singleton for this thread

---

### Context.reset_current

Reset the thread-local context (useful for test teardown).

**Returns:**
- nil

**Example:**
```ruby
# In test teardown
def teardown
  Context.reset_current
end
```

---

## Full Example

```ruby
require 'reality_marble'

class FileServiceTest < Test::Unit::TestCase
  def test_file_service_with_multiple_expectations
    # Define expectations
    marble = RealityMarble.chant do
      expect(File, :exist?) { |path| path == '/important/file' }
      expect(File, :read) { |path| "Mocked content" }
      expect(FileUtils, :mkdir_p) { |dir| true }
    end

    # Activate and test
    marble.activate do
      assert File.exist?('/important/file')
      refute File.exist?('/other/file')
      assert_equal "Mocked content", File.read('/important/file')
      FileUtils.mkdir_p('/new/dir')
    end

    # Inspect call history
    mkdir_calls = marble.calls_for(FileUtils, :mkdir_p)
    assert_equal 1, mkdir_calls.length
    assert_equal '/new/dir', mkdir_calls[0].args[0]
  end

  # Cleanup
  def teardown
    RealityMarble::Context.reset_current
  end
end
```

---

## DSL Chaining Examples

### Exact Match with Return Value
```ruby
expect(Calculator, :add)
  .with(2, 3)
  .returns(5)
```

### Any Arguments with Return Value
```ruby
expect(Logger, :info)
  .with_any
  .returns(nil)
```

### Exact Match with Block
```ruby
expect(Array, :map) do |&block|
  [1, 2, 3].map(&block)
end
```

### Exception on Match
```ruby
expect(Database, :connect)
  .with_any
  .raises(ConnectionError, "Connection failed")
```

---

## Error Handling

### NoMethodError (Method Not Defined)
If you try to mock a method that doesn't exist on the class, a warning is issued:
```
⚠️  Warning: Mocking non-existent method MyClass#undefined_method (no original to restore)
```
The mock is still created, but no original method exists to restore.

---

## Thread Safety

Reality Marble is thread-safe:
- Each thread has its own `Context.current`
- Mocks in one thread don't affect other threads
- Nested marbles are safe within a thread

```ruby
Thread.new do
  RealityMarble.chant { expect(...) }.activate do
    # Only affects this thread
  end
end

Thread.new do
  # This thread has its own Context
  # Previous marble doesn't affect here
end
```

---

## Version Information

- **Reality Marble**: 0.1.0+
- **Ruby**: 3.4+
- **No External Dependencies**: Pure Ruby implementation
