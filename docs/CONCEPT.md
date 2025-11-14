# Reality Marble: Core Concepts

## The Metaphor

**Reality Marble** (固有結界) is inspired by TYPE-MOON's magical concept: a technique to create a temporary "reality" within a localized space where the caster's rules apply.

In Ruby testing, this translates to:
- A **temporary test reality** where method behaviors are overridden
- **Scope-limited duration** - mocks exist only within the activation block
- **Complete restoration** - original methods are always restored afterward
- **No global pollution** - other tests are completely unaffected

## The Problem It Solves

### Before Reality Marble

Traditional mocking libraries use global state or complex setup/teardown:

```ruby
# RSpec approach (global mocks)
allow(File).to receive(:exist?).and_return(true)
# File is now mocked globally in the example
# Restoration happens via RSpec's framework

# Minitest approach (instance mocks)
File.stub(:exist?, true) do
  # Mocks active only in block
end
# But this requires understanding stubbing DSL
```

### With Reality Marble

A simple, intuitive API that mirrors the magical concept:

```ruby
# Define your "reality" (expectations)
RealityMarble.chant do
  expect(File, :exist?) { |path| path == '/tmp/test' }
end.activate do
  # Inside this block, your reality applies
  assert File.exist?('/tmp/test')
end
# Outside the block, original reality restored
```

## Key Design Principles

### 1. **Lexical Scope Isolation**
- Mocks are active **only** within the `activate` block
- No global state pollution
- Thread-safe by design (each thread has its own Context)

```ruby
RealityMarble.chant { expect(...) }.activate do
  # Mock active here
  subject.method_call  # Uses mock
end

# Mock inactive here
subject.method_call  # Uses original
```

### 2. **Method Restoration Guarantee**
- Original methods are **always** restored
- Even if test fails or raises exception
- Uses ensure blocks internally

```ruby
RealityMarble.chant { expect(...) }.activate do
  raise "Test fails"  # Exception raised
end
# Original method is still restored!
```

### 3. **Zero Configuration**
- No global setup/teardown needed
- No configuration files
- Works with any test framework

```ruby
# Works in Test::Unit
class MyTest < Test::Unit::TestCase
  def test_something
    RealityMarble.chant { expect(...) }.activate { ... }
  end
end

# Works in RSpec
describe "Something" do
  it { RealityMarble.chant { expect(...) }.activate { ... } }
end
```

### 4. **Nested Marble Support**
- Multiple marbles can be active simultaneously
- Each captures its own expectations
- Newer marbles take precedence

```ruby
marble1 = RealityMarble.chant { expect(Foo, :bar) { 1 } }
marble2 = RealityMarble.chant { expect(Foo, :bar) { 2 } }

marble1.activate do
  assert_equal 1, Foo.bar

  marble2.activate do
    assert_equal 2, Foo.bar  # marble2 takes precedence
  end

  assert_equal 1, Foo.bar  # Back to marble1
end
```

## Architecture

### Three Core Components

#### 1. **Marble** (Entry Point)
- Container for expectations
- Manages activation/deactivation
- Tracks call history

```ruby
marble = RealityMarble.chant do
  expect(Class, :method) { "mock" }
end
marble.calls_for(Class, :method)  # Access call history
```

#### 2. **Expectation** (Behavior Definition)
- Defines what to mock and how
- Supports matching and return values
- Can use blocks or DSL

```ruby
expect(File, :exist?)           # Block expects args
  .with('/tmp/test')            # Exact argument matching
  .returns(true)                # Return value
```

#### 3. **Context** (Execution Environment)
- Thread-local singleton
- Manages activation stack
- Handles backup/restore lifecycle

```
Thread A: [Context A]
  ├─ marble1 (File mocks)
  └─ marble2 (HTTP mocks)

Thread B: [Context B]
  └─ marble3 (Database mocks)
```

### Execution Flow

```
1. chant(&block)
   └─ Create Marble instance
   └─ Execute block (define expectations via expect)
   └─ Return Marble

2. .activate(&block)
   └─ Get thread-local Context
   └─ Context.push(self)
      ├─ First push: backup originals, define mocks
      └─ Subsequent pushes: reuse backups
   └─ Execute test block
   └─ Context.pop()
      ├─ Remove marble from stack
      └─ Last pop: restore originals
```

## Why Reality Marble?

### Compared to RSpec Mocks
| Aspect | RSpec | Reality Marble |
|--------|-------|----------------|
| **Test Framework** | RSpec only | Any framework |
| **API** | Rich DSL | Simple and intuitive |
| **Scope** | Per-example (implicit) | Block-based (explicit) |
| **Restoration** | Framework-managed | Guaranteed via ensure |
| **Thread Safety** | Yes | Yes (explicit thread-local) |

### Compared to Minitest Mock
| Aspect | Minitest | Reality Marble |
|--------|----------|----------------|
| **Simplicity** | Minimal | Equally minimal |
| **Ruby 3.4+** | Not leveraged | Yes (frozen strings, Prism-ready) |
| **Call History** | Limited | Full history tracking |
| **Return Sequences** | Manual | Built-in support |

## Common Patterns

### Simple Stub (Single Return Value)
```ruby
RealityMarble.chant do
  expect(User, :find) { User.new(id: 1, name: "Alice") }
end.activate do
  assert_equal "Alice", User.find(1).name
end
```

### Conditional Mock (Block Logic)
```ruby
RealityMarble.chant do
  expect(File, :exist?) do |path|
    path.start_with?('/mock')  # Conditional logic
  end
end.activate do
  assert File.exist?('/mock/file')
  refute File.exist?('/real/file')
end
```

### Call History Inspection
```ruby
marble = RealityMarble.chant do
  expect(Logger, :info) { nil }
end.activate do
  Logger.info("test message")
end

calls = marble.calls_for(Logger, :info)
assert_equal 1, calls.length
assert_equal "test message", calls.first.args[0]
```

## The Magic Behind It

Reality Marble works without magical tricks:

1. **Method Backup**: Original methods are saved via `alias_method`
2. **Dynamic Redefinition**: New mock methods are defined via `define_method`
3. **Stack Management**: Thread-local stack tracks active marbles
4. **Context Verification**: Mocks check if calling context owns them
5. **Guaranteed Restoration**: `ensure` blocks guarantee cleanup

No global state, no hidden side effects, no monkey patching beyond the test scope.

## The Reality Marble Philosophy

> **Create a temporary test reality, and let it vanish.**

This mirrors the TYPE-MOON concept:
- **Creation**: `chant do ... end` creates the reality
- **Application**: `.activate do ... end` applies it
- **Dissolution**: `)` at the end dissolves it completely
- **Zero Trace**: Original reality is perfectly restored

Reality Marble respects Ruby's principles: simple, explicit, and controlled.
