# Reality Marble API Reference

Complete API documentation for Reality Marble v2.0.

## Module Methods

### RealityMarble.chant(capture: nil, &block)

Create a new Reality Marble and define method mocks using native Ruby syntax.

**Parameters:**
- `capture` (Hash, optional): Variables to pass into the block for state tracking
- `block`: Block to execute in the context of a new Marble instance

**Returns:**
- `Marble` instance (call `.activate` to use the mocks)

**Example:**
```ruby
marble = RealityMarble.chant do
  File.define_singleton_method(:exist?) do |path|
    path == '/mock/path'
  end

  MyClass.define_method(:save) do
    true
  end
end
```

---

## Marble Class

### RealityMarble.chant(capture: {...}) { |cap| ... }

Define mocks and capture objects for verification.

**How It Works:**

1. **Detection Phase**: All methods defined via `define_method`/`define_singleton_method` are automatically detected using ObjectSpace inspection
2. **Storage Phase**: Detected methods are immediately removed and stored as UnboundMethod objects
3. **Activation Phase**: Stored methods are restored only when `.activate` is called
4. **Cleanup Phase**: Methods are automatically removed when the activate block exits

**Parameters:**
- `capture` (Hash): Variables to pass as a hash available in the block

**Block Parameter:**
- `cap` (Hash): Access to the captured variables

**Example with capture:**
```ruby
state = { called: false, args: nil }

marble = RealityMarble.chant(capture: { state: state }) do |cap|
  Kernel.define_method(:system) do |cmd|
    cap[:state][:called] = true
    cap[:state][:args] = cmd
    true
  end
end

marble.activate do
  system('git clone https://example.com/repo.git')
end

# Verify state
assert state[:called]
assert_match /git clone/, state[:args]
```

---

### marble.calls_for(target_class, method_name)

Get all recorded calls to a mocked method.

**Parameters:**
- `target_class` (Class, Module): Class/module to look up
- `method_name` (Symbol): Method name

**Returns:**
- `Array<CallRecord>` - List of all calls (empty if not mocked or not called)

**Example:**
```ruby
marble = RealityMarble.chant do
  Logger.define_singleton_method(:info) { |msg| nil }
end.activate do
  Logger.info("Started")
  Logger.info("Completed")
end

calls = marble.calls_for(Logger, :info)
assert_equal 2, calls.length
assert_equal "Started", calls[0].args[0]
assert_equal "Completed", calls[1].args[0]
```

---

### marble.activate(&block)

Activate the mocks defined in the chant block.

**How It Works:**
1. Stored mock methods are restored
2. Test code executes (mocks are active)
3. All mocks are automatically removed when block exits (via ensure)

**Parameters:**
- `block`: Test code to execute

**Returns:**
- Result of the test block

**Example:**
```ruby
result = marble.activate do
  File.exist?('/mock/path')  # Calls mock
end
assert_equal true, result
```

---

## Native Syntax Examples

### Singleton Method Mocking

Mock class-level methods using `define_singleton_method`:

```ruby
RealityMarble.chant do
  File.define_singleton_method(:exist?) do |path|
    path == '/mock/path'
  end
end.activate do
  assert File.exist?('/mock/path')
  refute File.exist?('/other/path')
end
```

### Instance Method Mocking

Mock instance-level methods using `define_method`:

```ruby
RealityMarble.chant do
  User.define_method(:save) do
    @saved = true
  end
end.activate do
  user = User.new
  assert user.save
end
```

### Conditional Mock Logic

Use Ruby conditionals directly in mock definitions:

```ruby
RealityMarble.chant do
  MyAPI.define_singleton_method(:fetch) do |url|
    if url =~ /valid/
      { success: true, data: "content" }
    else
      raise ArgumentError, "Invalid URL"
    end
  end
end.activate do
  result = MyAPI.fetch('/valid/resource')
  assert result[:success]

  assert_raises(ArgumentError) { MyAPI.fetch('/invalid') }
end
```

### State Capture and Verification

Track method calls and capture state using the `capture:` option:

```ruby
call_log = []

RealityMarble.chant(capture: { log: call_log }) do |cap|
  Logger.define_singleton_method(:info) do |message, level = :info|
    cap[:log] << { message: message, level: level }
  end
end.activate do
  Logger.info("Started", :debug)
  Logger.info("Completed", :info)
end

# Verify
assert_equal 2, call_log.length
assert_equal "Started", call_log[0][:message]
assert_equal :debug, call_log[0][:level]
```

### Nested Mocks

Define multiple mocks in one chant block:

```ruby
RealityMarble.chant do
  File.define_singleton_method(:exist?) do |path|
    path.start_with?('/mock')
  end

  File.define_singleton_method(:read) do |path|
    "mock content"
  end

  FileUtils.define_singleton_method(:mkdir_p) do |dir|
    true
  end
end.activate do
  assert File.exist?('/mock/file')
  assert_equal "mock content", File.read('/mock/file')
  FileUtils.mkdir_p('/mock/dir')
end
```

---

## CallRecord Class

Represents a single method call recorded in call history.

### call_record.args

Array of positional arguments passed to the method.

**Returns:**
- Array

**Example:**
```ruby
calls = marble.calls_for(Logger, :info)
message = calls[0].args[0]  # First argument of first call
```

---

### call_record.kwargs

Hash of keyword arguments passed to the method.

**Returns:**
- Hash

**Example:**
```ruby
calls = marble.calls_for(API, :fetch)
timeout = calls[0].kwargs[:timeout]  # Keyword argument value
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
  RealityMarble::Context.reset_current
end
```

---

## Complete Example

```ruby
require 'reality_marble'
require 'test-unit'

class FileServiceTest < Test::Unit::TestCase
  def test_file_service_with_native_syntax
    # Track state across method calls
    operations = []

    marble = RealityMarble.chant(capture: { ops: operations }) do |cap|
      File.define_singleton_method(:exist?) do |path|
        cap[:ops] << { op: :exist?, path: path }
        path == '/important/file'
      end

      File.define_singleton_method(:read) do |path|
        cap[:ops] << { op: :read, path: path }
        "Mocked content"
      end

      FileUtils.define_singleton_method(:mkdir_p) do |dir|
        cap[:ops] << { op: :mkdir_p, dir: dir }
        true
      end
    end

    marble.activate do
      assert File.exist?('/important/file')
      refute File.exist?('/other/file')
      assert_equal "Mocked content", File.read('/important/file')
      FileUtils.mkdir_p('/new/dir')
    end

    # Verify call history
    assert_equal 4, operations.length
    assert_equal :exist?, operations[0][:op]
    assert_equal '/important/file', operations[0][:path]

    mkdir_calls = marble.calls_for(FileUtils, :mkdir_p)
    assert_equal 1, mkdir_calls.length
    assert_equal '/new/dir', mkdir_calls[0].args[0]
  end

  def teardown
    RealityMarble::Context.reset_current
  end
end
```

---

## Method Detection

Reality Marble automatically detects method definitions using ObjectSpace inspection:

### What Gets Detected

✅ Singleton methods via `Class.define_singleton_method(:name) { ... }`
✅ Instance methods via `Class.define_method(:name) { ... }`
✅ Multiple method definitions in one chant block
✅ Nested method definitions

### How It Works

```
1. Before chant block: Snapshot all existing methods via ObjectSpace
2. Execute chant block: User defines new methods via define_method
3. After chant block: Snapshot methods again and compute diff
4. Store: Save new methods as UnboundMethod objects
5. Remove: Delete methods from the system (they're only in storage)
6. On activate: Restore only during test block
7. On cleanup: Remove again automatically
```

---

## Thread Safety

Reality Marble is fully thread-safe:

- Each thread has its own `Context.current`
- Mocks in one thread don't affect other threads
- Nested marbles are safe within a thread

```ruby
Thread.new do
  RealityMarble.chant do
    File.define_singleton_method(:read) { "thread A" }
  end.activate do
    # Only affects this thread
  end
end

Thread.new do
  # This thread has its own Context
  # Previous marble doesn't affect here
  File.read('/path')  # Uses original
end
```

---

## Key Features of v2.0

| Feature | Implementation |
|---------|----------------|
| **Native Syntax** | Use Ruby's standard `define_method`/`define_singleton_method` |
| **No DSL** | Zero custom syntax - pure Ruby |
| **Perfect Isolation** | Methods automatically removed after activate block |
| **State Capture** | `capture:` option for before/after verification |
| **Call History** | `calls_for()` tracks all method invocations |
| **Thread Safe** | Thread-local Context stack |
| **Framework Agnostic** | Works with Test::Unit, RSpec, or any framework |
| **Nested Support** | Multiple marbles can be active simultaneously |

---

## Version Information

- **Reality Marble**: 2.0.0+
- **Ruby**: 3.4+
- **No External Dependencies**: Pure Ruby implementation
