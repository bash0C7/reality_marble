# Reality Marble: Core Concepts

## 🎭 The Fate Metaphor

**Reality Marble** (固有結界) is inspired by TYPE-MOON's Fate series: a magical technique to create a temporary "reality" within a bounded field where the caster's inner world overwrites the actual world.

In Ruby testing, this translates to:
- A **temporary test reality** where method behaviors are overridden
- **Scope-limited duration** - mocks exist only within the activation block
- **Complete restoration** - original methods are always restored afterward
- **No global pollution** - other tests are completely unaffected

Like Fate's Reality Marble, when the test block exits, the boundary dissolves and reality returns to normal.

## The Problem It Solves

### Existing Mocking Libraries

Traditional mocking libraries have different challenges:

```ruby
# RSpec approach (global state)
allow(File).to receive(:exist?).and_return(true)
# File is now mocked globally until cleanup

# Minitest approach (requires DSL knowledge)
File.stub(:exist?, true) do
  # Must understand stubbing syntax
end
```

### Reality Marble's Solution

Pure Ruby syntax - just use native `define_method`:

```ruby
# Define your "reality" (mock methods)
RealityMarble.chant do
  File.define_singleton_method(:exist?) do |path|
    path == '/tmp/test'
  end
end.activate do
  # Inside this block, your reality applies
  assert File.exist?('/tmp/test')
end
# Outside the block, original methods restored automatically
```

**Three phases:**
1. **Definition** (`chant`): Define mocks using native Ruby
2. **Activation** (`activate`): Mocks are active only here
3. **Cleanup** (auto): Methods restored when block exits

## Key Design Principles

### 1. **Native Ruby Syntax - No Custom DSL**

Use Ruby's standard `define_method` and `define_singleton_method` directly. No proprietary syntax to learn:

```ruby
RealityMarble.chant do
  # Just plain Ruby method definitions
  File.define_singleton_method(:read) do |path|
    "mock content for #{path}"
  end

  MyClass.define_method(:save) do
    true
  end
end.activate { ... }
```

### 2. **Lexical Scope Isolation**

Mocks are active **only** within the `activate` block. No global state pollution:

```ruby
RealityMarble.chant do
  File.define_singleton_method(:exist?) { true }
end.activate do
  File.exist?('/path')  # => true (mock)
end

File.exist?('/path')  # => actual behavior (original method)
```

### 3. **Perfect Test Isolation**

Methods are **automatically** restored when the block exits, even on exception:

```ruby
RealityMarble.chant do
  MyClass.define_method(:dangerous) { raise "Boom!" }
end.activate do
  raise "Oops!"  # Exception raised
end
# MyClass#dangerous is still restored!
```

### 4. **Capture Objects for Before/After Verification**

The `capture:` option (inspired by mruby/c) lets you capture state and verify behavior:

```ruby
state = { called: false, args: nil }

RealityMarble.chant(capture: { state: state }) do |cap|
  Kernel.define_method(:system) do |cmd|
    cap[:state][:called] = true
    cap[:state][:args] = cmd
    true
  end
end.activate do
  system('git clone ...')
end

# Verify after activation
assert state[:called]
assert_match /git clone/, state[:args]
```

### 5. **Thread-Safe by Design**

Each thread has its own Context. Multiple threads can use Reality Marble simultaneously without interference:

```ruby
Thread.new { RealityMarble.chant { ... }.activate { ... } }
Thread.new { RealityMarble.chant { ... }.activate { ... } }
# Each thread's mocks are isolated
```

### 6. **Nested Marble Support**

Multiple marbles can be active simultaneously. Newer marbles take precedence:

```ruby
marble1 = RealityMarble.chant do
  File.define_singleton_method(:read) { "from marble1" }
end

marble2 = RealityMarble.chant do
  File.define_singleton_method(:read) { "from marble2" }
end

marble1.activate do
  assert_equal "from marble1", File.read('/any')

  marble2.activate do
    assert_equal "from marble2", File.read('/any')  # marble2 takes precedence
  end

  assert_equal "from marble1", File.read('/any')  # Back to marble1
end
```

## Architecture

### Lazy Method Application Pattern

Reality Marble uses three phases:

#### 1. **Definition Phase** (`chant`)
- User calls `RealityMarble.chant { ... }`
- All methods defined via `define_method` in the block are automatically detected via ObjectSpace
- Detected methods are **immediately removed** and stored as UnboundMethod objects
- User gets back a Marble object (methods are NOT in the global state yet)

#### 2. **Activation Phase** (`activate`)
- User calls `.activate { ... }`
- Stored methods are restored just before executing the test block
- Methods are available during test execution
- Block executes with mocks active

#### 3. **Cleanup Phase** (automatic)
- `ensure` block triggers after activate completes
- All mocked methods are removed
- Original methods are restored if they existed before
- Perfect isolation guaranteed

### Why This Design?

```
✅ Simple: No complex DSL or dispatch logic
✅ Safe: Perfect test isolation, zero leakage
✅ Native: Uses standard Ruby define_method
✅ Elegant: Three-phase lifecycle is testable
✅ Observable: Methods detected via ObjectSpace (no magic)
```

## Common Patterns

### Simple Singleton Method Mock

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

### Conditional Logic in Mocks

```ruby
RealityMarble.chant do
  MyAPI.define_singleton_method(:fetch) do |url|
    if url =~ /valid/
      { success: true }
    else
      { error: "Invalid URL" }
    end
  end
end.activate do
  assert_equal true, MyAPI.fetch('/valid/resource')[:success]
  assert MyAPI.fetch('/invalid')[:error]
end
```

### Instance Method Mocking

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

### Capture with State Tracking

```ruby
calls = []

RealityMarble.chant(capture: { calls: calls }) do |cap|
  Logger.define_singleton_method(:info) do |msg|
    cap[:calls] << msg
  end
end.activate do
  Logger.info("Started")
  Logger.info("Completed")
end

assert_equal 2, calls.length
assert_equal "Started", calls[0]
```

## Execution Flow

```
RealityMarble.chant do
  MyClass.define_method(:foo) { "mock" }
end.activate do
  MyClass.new.foo  # => "mock"
end
# => "mock" is now removed, original behavior restored

Flow:
1. ObjectSpace snapshot before user's block
2. Execute block (methods defined)
3. ObjectSpace snapshot after user's block
4. Detect new methods (diff between snapshots)
5. Remove detected methods from the system
6. Store as UnboundMethod objects
7. On .activate:
   ├─ Restore stored methods
   ├─ Execute test block
   └─ Remove methods again
```

## The Reality Marble Philosophy

> **Create a temporary test reality, and let it vanish.**

This mirrors the TYPE-MOON concept perfectly:

- **Creation**: `chant do ... end` creates the reality using native Ruby syntax
- **Application**: `.activate do ... end` applies it to your test
- **Dissolution**: Block exit dissolves it completely
- **Zero Trace**: Original reality is perfectly restored

Reality Marble respects Ruby's principles: **simple**, **explicit**, and **controlled**.

### Benefits Summary

| Benefit | How It Works |
|---------|-------------|
| **No DSL** | Use Ruby's native `define_method` |
| **Perfect Isolation** | Methods removed after activate block |
| **Easy Verification** | `capture:` option tracks state |
| **Thread Safe** | Thread-local Context stack |
| **Framework Agnostic** | Works with any test framework |
| **Natural Ruby** | Reads like real Ruby code |
