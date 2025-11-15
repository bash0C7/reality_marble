# Reality Marble (固有結界)

Next-generation mock/stub library for Ruby 3.4+

## Overview

**Reality Marble** (固有結界 - "fixed boundary") is a modern mock/stub library for Ruby 3.4+. Inspired by TYPE-MOON's Fate series, it creates a temporary "reality" where method behaviors are overridden only within specific test scopes.

**Like Fate's magic**: A Reality Marble is a bounded field that overwrites reality with the caster's inner world. When the boundary dissolves, reality returns to normal. In testing:

- **`chant`**: Define your alternative reality (write mock methods using native Ruby)
- **`activate`**: Enter that reality (mocks are ONLY active in this block)
- **Block exit**: Reality dissolves (all mocks automatically removed, original methods restored)

**Pure Ruby, no DSL**: Just use `define_method`/`define_singleton_method` directly. No custom syntax to learn.

**Perfect isolation**: Mocks never leak between tests. Every test gets a clean slate.

Key features:
- 🎭 **Fate's Reality Marble Philosophy**: Temporary reality that vanishes cleanly
- 🎯 **Native Ruby Syntax**: Use `define_method` directly, no custom DSL
- ✨ **Perfect Isolation**: Mocks completely removed after `activate` block (zero leakage)
- 🧪 **Test::Unit focused**: Works with Test::Unit, RSpec, or any framework
- 🔒 **Thread-safe**: Each thread has its own mock Context
- 📝 **Simple API**: `chant` to define, `activate` to execute
- 📦 **Variable Capture**: mruby/c-style `capture:` option for easy before/after verification

## Requirements

- Ruby >= 3.4.0
- No external runtime dependencies

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'reality_marble'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install reality_marble
```

## Quick Start

### Basic Usage

```ruby
require 'reality_marble'
require 'test-unit'

class FileOperationsTest < Test::Unit::TestCase
  def test_file_operations_with_mock
    # Define a Reality Marble with method mocks
    test_class = File

    RealityMarble.chant do
      test_class.define_singleton_method(:exist?) do |path|
        path == '/mock/path'
      end
    end.activate do
      # Inside this block, mocked methods are active
      assert test_class.exist?('/mock/path')
      refute test_class.exist?('/other/path')
    end

    # Outside the block, original methods are restored
    assert test_class.exist?(__FILE__)
  end
end
```

### Using capture: for Variable Passing

Pass local variables into the mock block using `capture:` (mruby/c style):

```ruby
class GitCommandTest < Test::Unit::TestCase
  def test_git_clone
    git_called = false
    cmd_match = nil

    RealityMarble.chant(capture: {git_called: git_called, cmd_match: cmd_match}) do |cap|
      module Kernel
        define_method(:system) do |cmd, options = {}|
          cap[:git_called] = true
          cap[:cmd_match] = cmd.match?(/git clone/)
          true  # Simulate success
        end
      end
    end.activate do
      system('git clone https://example.com/repo.git')
    end

    assert git_called
    assert cmd_match
  end
end
```

Note: In standard mruby, variables are automatically in scope. But in mruby/c (and this implementation), the `capture:` option provides that functionality.

### Mocking Multiple Methods

```ruby
class CalculatorTest < Test::Unit::TestCase
  def test_math_operations
    calculator = Class.new

    RealityMarble.chant do
      calculator.define_singleton_method(:add) do |a, b|
        a + b
      end

      calculator.define_singleton_method(:multiply) do |a, b|
        a * b
      end
    end.activate do
      assert_equal 15, calculator.add(10, 5)
      assert_equal 50, calculator.multiply(10, 5)
    end
  end
end
```

### Mocking Instance Methods

```ruby
class UserTest < Test::Unit::TestCase
  def test_user_save
    user_class = Class.new

    RealityMarble.chant do
      user_class.define_method(:save) do
        puts "Mock: User saved to database"
        true
      end
    end.activate do
      user = user_class.new
      assert user.save
    end
  end
end
```

## API Reference

### RealityMarble.chant

Defines a new Reality Marble context for mocking methods.

**Syntax:**
```ruby
RealityMarble.chant(capture: nil) { |cap| ... }
```

**Parameters:**
- `capture` (Hash, optional): Variables to pass into the block. Accessed via the block parameter.

**Returns:** Marble object (call `.activate` to use the mocks)

**Block parameter:**
- `cap` (Hash): Contains the variables passed via `capture:` option

**Example:**
```ruby
marble = RealityMarble.chant do
  SomeClass.define_singleton_method(:foo) { "mocked" }
end
```

**With variables:**
```ruby
var = {}
marble = RealityMarble.chant(capture: {var: var}) do |cap|
  SomeClass.define_singleton_method(:foo) do
    cap[:var][:called] = true
  end
end
```

### Marble#activate

Activates the mocks defined in the chant block. Methods are available only within the block.

**Syntax:**
```ruby
marble.activate { ... }
```

**Returns:** The result of the block

**Example:**
```ruby
result = RealityMarble.chant do
  File.define_singleton_method(:read) { |path| "contents" }
end.activate do
  File.read('/path/to/file')  # Returns "contents"
end
```

## How It Works

Reality Marble uses three key mechanisms:

1. **Method Definition Detection**: When you call `chant`, the library detects which methods you define using `define_method`.

2. **Lazy Application**: The defined methods are removed after the chant block, then reapplied during `activate` so mocks are only active when needed.

3. **Automatic Cleanup**: After the activate block exits, all mocks are removed and original methods are restored.

This ensures mocks don't leak across tests and maintain perfect isolation.

## Thread Safety

Reality Marble uses thread-local storage for the mock context stack, making it safe for concurrent test execution.

## Testing

Run the test suite:

```bash
bundle exec rake test
```

## Contributing

Bug reports and pull requests are welcome on GitHub.

## License

MIT License
