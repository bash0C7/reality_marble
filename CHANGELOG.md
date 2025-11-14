# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-11-15

### BREAKING CHANGES

Complete API redesign. All existing code using the `expect` DSL must be updated.

**Removed:**
- `Marble#expect` method and entire Expectation DSL
- `expect(target, :method) { ... }` syntax
- `.with()` matcher chain, `.returns()` return value setting, `.raises()` exception setting
- `RealityMarble.mock()` helper method

**Why:** The old DSL added unnecessary abstraction. The new native syntax is simpler and leverages Ruby's built-in `define_method`.

### Added

#### Native Syntax API
- Define mocks using Ruby's native `define_method` directly
- No custom DSL or matchers required

**Example:**
```ruby
RealityMarble.chant do
  File.define_singleton_method(:exist?) do |path|
    path == '/mock/path'
  end
end.activate do
  File.exist?('/mock/path')
end
```

#### Variable Capture (mruby/c style)
- New `capture:` option for passing local variables into blocks
- Solves closure scoping elegantly

```ruby
git_called = false
RealityMarble.chant(capture: {git_called: git_called}) do |cap|
  Kernel.define_method(:system) do |cmd|
    cap[:git_called] = true
  end
end.activate { system('git clone') }
```

#### Lazy Method Application Pattern
- Methods detected during `chant`, removed immediately
- Reapplied only during `activate` block execution
- Perfect test isolation with zero leakage

### Changed

#### Architecture Simplification
- Removed Expectation class entirely
- Simplified Context to bare stack management
- Marble manages its own method lifecycle
- No more complex mock method dispatch logic

#### Implementation
- Method detection via `ObjectSpace.each_object(Module)`
- Methods stored as `UnboundMethod` objects
- Three-phase lifecycle: Definition → Activation → Cleanup

### Fixed
- Perfect test isolation: mocks never leak across tests
- No warning spam for mocking non-existent methods
- Simpler, more maintainable codebase

### Migration from v1.x

Replace `expect` with native `define_method`:
```ruby
# v1.x
expect(File, :exist?) { |path| path == "/tmp" }

# v2.0
File.define_singleton_method(:exist?) do |path|
  path == "/tmp"
end
```

Replace `with()` matching with Ruby conditionals:
```ruby
# v1.x
expect(MyClass, :process).with(10).returns(20)

# v2.0
MyClass.define_singleton_method(:process) do |x|
  return 20 if x == 10
end
```

Use `capture:` for variable passing:
```ruby
my_var = {}
RealityMarble.chant(capture: {my_var: my_var}) do |cap|
  SomeClass.define_singleton_method(:foo) do
    cap[:my_var][:called] = true
  end
end
```

## [0.1.0] - 2025-11-13

### Added
- Initial gem structure
- Core API: `RealityMarble.chant` and `marble.activate`
- Mock/stub support via `marble.expect`
- Method restoration via ensure blocks (alias_method approach for C extensions)
- Test::Unit integration
- SimpleCov coverage reporting
- RuboCop configuration
- CI/CD pipeline with GitHub Actions
- Comprehensive documentation (README, CLAUDE.md)
- Basic mock/stub functionality
- Ruby 3.4+ support

[Unreleased]: https://github.com/bash0C7/reality_marble/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bash0C7/reality_marble/releases/tag/v0.1.0
