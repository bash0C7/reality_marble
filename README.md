# Reality Marble (固有結界)

Next-generation mock/stub library for Ruby 3.4+

## Overview

**Reality Marble** (固有結界) is a modern mock/stub library that creates isolated, lexically-scoped test doubles for Ruby 3.4+. Inspired by TYPE-MOON's metaphor, it creates a temporary "reality" where method behaviors are overridden only within specific test scopes.

Key features:
- 🎯 **Lexically scoped**: Mocks are isolated to specific test contexts
- 🚀 **Ruby 3.4+**: Leverages modern Ruby features
- 🧪 **Test::Unit focused**: Designed for Test::Unit workflow (but framework-agnostic)
- 🔒 **Thread-safe**: Safe for concurrent test execution
- 📝 **Simple API**: `chant` to define, `activate` to execute

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
    # Define a Reality Marble with expectations
    RealityMarble.chant do
      expect(File, :exist?) { |path| path == '/mock/path' }
      expect(FileUtils, :rm_rf) { |path| puts "Mock: Would delete #{path}" }
    end.activate do
      # Inside this block, mocked methods are active
      assert File.exist?('/mock/path')
      refute File.exist?('/other/path')

      FileUtils.rm_rf('/some/path')  # Prints mock message
    end

    # Outside the block, original methods are restored
    assert_equal File.method(:exist?).source_location, nil  # Built-in method
  end
end
```

### Mocking System Commands

```ruby
class GitCommandTest < Test::Unit::TestCase
  def test_git_clone
    git_called = false

    RealityMarble.chant do
      expect(Kernel, :system) do |cmd|
        git_called = true
        assert_match(/git clone/, cmd)
        true  # Simulate success
      end
    end.activate do
      system('git clone https://example.com/repo.git')
    end

    assert git_called, "Git clone should have been called"
  end
end
```

### Stubbing for Return Values

```ruby
class ApiClientTest < Test::Unit::TestCase
  def test_api_response
    RealityMarble.chant do
      expect(Net::HTTP, :get) do |uri|
        case uri.to_s
        when /users/
          '{"users": [{"id": 1, "name": "Alice"}]}'
        when /posts/
          '{"posts": []}'
        else
          '{}'
        end
      end
    end.activate do
      response = Net::HTTP.get(URI('https://api.example.com/users'))
      assert_equal '{"users": [{"id": 1, "name": "Alice"}]}', response
    end
  end
end
```

### Multiple Expectations

```ruby
RealityMarble.chant do
  expect(File, :exist?) { |path| path.start_with?('/mock') }
  expect(File, :read) { |path| "Mock content of #{path}" }
  expect(FileUtils, :mkdir_p) { |path| true }
end.activate do
  assert File.exist?('/mock/file.txt')
  assert_equal "Mock content of /mock/file.txt", File.read('/mock/file.txt')
  FileUtils.mkdir_p('/mock/dir')
end
```

## API Reference

### `RealityMarble.chant(&block)`

Creates a new Reality Marble context.

**Parameters:**
- `block` (optional): Block for defining expectations using `expect`

**Returns:**
- `Marble` instance

**Example:**
```ruby
marble = RealityMarble.chant do
  expect(File, :exist?) { |path| true }
end
```

### `marble.expect(target_class, method_name, &block)`

Defines an expectation (mock/stub) for a method.

**Parameters:**
- `target_class`: The class or module containing the method
- `method_name`: Symbol representing the method name
- `block`: The mock implementation (receives method arguments)

**Returns:**
- `self` (for method chaining)

**Example:**
```ruby
marble.expect(File, :exist?) { |path| path == '/expected' }
marble.expect(FileUtils, :rm_rf) { |path| puts "Deleting #{path}" }
```

### `marble.activate(&test_block)`

Activates the Reality Marble for the duration of the test block.

**Parameters:**
- `test_block`: Block to execute with mocks active

**Returns:**
- Result of the test block

**Example:**
```ruby
result = marble.activate do
  # Your test code here
  File.exist?('/some/path')  # Calls mock
end
```

## Design Philosophy

Reality Marble follows these principles:

1. **Isolation**: Mocks are isolated to specific scopes, never polluting the global environment
2. **Restoration**: Original methods are always restored after the test block
3. **Simplicity**: Minimal API surface, easy to understand and use
4. **Safety**: Thread-safe by design, supports concurrent test execution
5. **Ruby 3.4+**: Takes advantage of modern Ruby features and defaults

## Architecture

Reality Marble uses a combination of techniques:

- **Method redefinition**: Temporarily redefines target methods
- **Ensure blocks**: Guarantees restoration even if tests fail
- **Thread-local storage**: Isolates mocks per thread (future enhancement)

For detailed architectural discussion, see [REALITY_MARBLE_TODO.md](../../REALITY_MARBLE_TODO.md) in the parent project.

## Comparison with Other Libraries

| Feature | Reality Marble | RSpec Mocks | Minitest Mock |
|---------|----------------|-------------|---------------|
| Ruby Version | 3.4+ | 2.x+ | 2.x+ |
| Test Framework | Any (Test::Unit focused) | RSpec | Minitest |
| Scope Isolation | Lexical | Per-example | Manual |
| API Complexity | Minimal (`chant`/`activate`) | Rich DSL | Simple |
| Thread Safety | Yes | Yes | Partial |

## Development

### Setup

```bash
cd lib/reality_marble
bundle install
```

### Running Tests

```bash
bundle exec rake test
```

### Running RuboCop

```bash
bundle exec rake rubocop
```

### Running CI (Tests + RuboCop + Coverage)

```bash
bundle exec rake ci
```

### Development Workflow (Auto-fix + Tests)

```bash
bundle exec rake dev
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bash0C7/reality_marble.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).

## Credits

- Inspired by TYPE-MOON's "Reality Marble" (固有結界) concept
- Part of the [picotorokko](https://github.com/bash0C7/picotorokko) project ecosystem
