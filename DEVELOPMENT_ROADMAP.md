# Reality Marble Development Roadmap

Next-generation mock/stub library for Ruby 3.4+ - Development guide for next session

## Current Status (v0.1.0)

### What We Have

**✅ Complete Gem Infrastructure**:
- Standalone gem structure in `lib/reality_marble/`
- CI/CD pipeline (GitHub Actions)
- Test suite: 10 tests, 100% pass, 95.12% line coverage, 72.22% branch coverage
- RuboCop: 0 violations
- Documentation: README, CLAUDE.md, CHANGELOG
- MIT License
- Integrated with picotorokko via `Gemfile` path dependency

**✅ Core Implementation (Simple Method Redefinition)**:
```ruby
# lib/reality_marble/lib/reality_marble.rb
module RealityMarble
  class Marble
    def activate
      # 1. Save original methods (both singleton and instance)
      # 2. Redefine methods with mock implementations
      # 3. Execute test block (yield)
      # 4. Restore original methods (ensure block)
    end
  end
end
```

**Features**:
- ✅ Singleton method mocking (`File.exist?`, `Net::HTTP.get`)
- ✅ Instance method mocking
- ✅ Automatic restoration via ensure blocks
- ✅ Simple API: `RealityMarble.chant { expect(...) }.activate { ... }`

### What We DON'T Have (Yet)

**Current limitations**:
- ❌ Call history tracking (how many times called, with what args)
- ❌ Argument matching (`with(...)` DSL)
- ❌ Return value sequences (`returns("first", "second", "third")`)
- ❌ Exception throwing (`raises(SomeError)`)
- ❌ Thread-safety (Thread-local storage)
- ❌ Nested activate support (Reference counting)
- ❌ TracePoint integration (案3.2 design)
- ❌ Refinements integration (案2 design)
- ❌ Prism AST transformation (案4 design)

### Honest Evaluation

**Reality Marble v0.1.0 is a prototype**. It works for basic use cases in picotorokko, but:
- Not production-ready for public gem release
- Lacks essential features compared to RSpec Mocks / Minitest Mock
- No competitive advantage over existing libraries yet

**However**, implementing designs from `REALITY_MARBLE_TODO.md` (案2/案3.2/案4) will unlock unique killer features.

---

## User's Philosophy and Strong Requirements

### Core Metaphor: TYPE-MOON's Reality Marble (固有結界)

**Concept**: Create a temporary "reality" where only specific behaviors are overridden, then return to normal reality.

**API Design Philosophy**:
- `chant` (詠唱): Define the marble's rules
- `activate` (発動): Execute the marble temporarily
- Marble automatically dissolves after execution (ensure block)

**Why this metaphor matters**:
- Intuitive for Japanese Ruby developers familiar with TYPE-MOON works
- Emphasizes **temporal isolation** and **automatic cleanup**
- Differentiates from generic "mock" terminology

### User's Strong Requirements (ABSOLUTE)

#### 1. 🎯 **Transparency Above All** (案4 Killer Feature)

**User's vision**: Tests should look like production code, with mocking happening "magically" behind the scenes.

```ruby
# User writes ZERO mock setup code
def test_git_clone_success
  system('git clone https://example.com/repo.git')
  assert File.exist?('dest/.git')
end

# Reality Marble (案4) intercepts via Prism AST transformation
# No explicit mock declarations needed
```

**Why**: Reduces test maintenance burden, makes tests readable as documentation.

#### 2. 🔒 **Lexical Scope Isolation** (案2 Core Strength)

**Requirement**: Mocks must NEVER leak outside the test case scope.

- ✅ Good: Mocks active only inside `activate { ... }` block
- ❌ Bad: Global method redefinition affecting other tests
- ✅ Good: Refinements-based scoping (案2)
- ❌ Bad: RSpec's `allow_any_instance_of` (global pollution)

**Why**: Prevents test interference, enables parallel test execution.

#### 3. 📝 **Natural Ruby Syntax** (Not a Foreign DSL)

**User prefers**:
```ruby
# Reality Marble style (Ruby-native)
expect(File, :exist?) { |path| path.start_with?("/mock") }
```

**Over**:
```ruby
# RSpec style (DSL-heavy)
allow(File).to receive(:exist?).with(start_with("/mock")).and_return(true)
```

**Why**: Lower learning curve, feels like writing plain Ruby.

#### 4. 🚫 **No Code Changes Required** (案4 Ultimate Goal)

**User's dream**: Add Reality Marble to existing test files without modifying test logic.

```ruby
# Before: Plain test
def test_foo
  system('git clone ...')
end

# After: Just add require at top, zero test changes
require 'reality_marble/auto' # ← Only addition
def test_foo
  system('git clone ...')  # ← Unchanged
end
```

**Why**: Enables gradual adoption, works with legacy tests.

#### 5. ⚡ **Ruby 3.4+ Exclusive Focus**

**No backward compatibility burden**:
- Use frozen string literals by default
- Leverage Prism APIs (Ruby 3.3+ parser)
- Use pattern matching, etc.

**Why**: Simplifies implementation, pushes Ruby forward.

---

## Detailed TODO with Priorities

### Phase 1: Essential Features (MUST HAVE for v0.2.0)

**Priority: ⭐⭐⭐⭐⭐ CRITICAL**

**Goal**: Make Reality Marble production-ready for picotorokko use cases.

#### 1.1 Call History Tracking

**TDD Cycle**:
```ruby
# RED: Test
def test_tracks_call_history
  marble = RealityMarble.chant do
    expect(File, :read)
  end

  marble.activate do
    File.read('/path1')
    File.read('/path2')
  end

  assert_equal 2, marble.calls_for(File, :read).count
  assert_equal ['/path1'], marble.calls_for(File, :read).first.args
end

# GREEN: Implementation
class Marble
  def initialize
    @expectations = []
    @call_history = Hash.new { |h, k| h[k] = [] }
  end

  def activate
    # Record each call: @call_history[[klass, method]] << { args: ..., kwargs: ..., result: ... }
  end

  def calls_for(klass, method)
    @call_history[[klass, method]]
  end
end
```

**Implementation files**:
- `lib/reality_marble/call_record.rb` (new)
- `lib/reality_marble.rb` (modify `Marble#activate`)
- `test/reality_marble/call_tracking_test.rb` (new)

**Coverage target**: ≥ 75% line, ≥ 55% branch

#### 1.2 Argument Matching DSL

**TDD Cycle**:
```ruby
# RED: Test
def test_argument_matching
  marble = RealityMarble.chant do
    expect(File, :read).with('/specific').returns('content')
    expect(File, :read).with_any.returns('default')
  end

  marble.activate do
    assert_equal 'content', File.read('/specific')
    assert_equal 'default', File.read('/other')
  end
end

# GREEN: Implementation
class Expectation
  def initialize(target_class, method_name)
    @target_class = target_class
    @method_name = method_name
    @matchers = []
  end

  def with(*args)
    @matchers << { type: :exact, args: args }
    self
  end

  def with_any
    @matchers << { type: :any }
    self
  end

  def returns(value)
    @return_value = value
    self
  end

  def matches?(args)
    # Implement matching logic
  end
end
```

**Implementation files**:
- `lib/reality_marble/expectation.rb` (new)
- `lib/reality_marble/matchers.rb` (new)
- `test/reality_marble/argument_matching_test.rb` (new)

#### 1.3 Exception Throwing

**TDD Cycle**:
```ruby
# RED: Test
def test_raises_exception
  marble = RealityMarble.chant do
    expect(File, :read).raises(Errno::ENOENT)
  end

  marble.activate do
    assert_raises(Errno::ENOENT) { File.read('/nonexistent') }
  end
end

# GREEN: Implementation
class Expectation
  def raises(exception_class, message = nil)
    @exception = { class: exception_class, message: message }
    self
  end

  def call(*args, **kwargs, &block)
    raise @exception[:class], @exception[:message] if @exception
    # ... normal mock execution
  end
end
```

**Implementation files**:
- `lib/reality_marble/expectation.rb` (modify)
- `test/reality_marble/exception_test.rb` (new)

### Phase 2: Advanced Design Implementation (SHOULD HAVE for v0.3.0)

**Priority: ⭐⭐⭐⭐ HIGH**

**Goal**: Implement 案3.2 (TracePoint + Upfront Bulk Redefinition) for production-grade architecture.

#### 2.1 案3.2 Architecture Migration

**Design rationale** (from `REALITY_MARBLE_TODO.md`):

**Why 案3.2 over current implementation**:
- ✅ Solves Production Code Boundary Problem (Refinements limitation)
- ✅ Thread-local context isolation
- ✅ Reference counting for nested activations
- ✅ Solves ensure block safety (TracePoint + method redefinition, NOT throw/catch)

**Implementation steps** (TDD cycles):

1. **Thread-local Context**:
   ```ruby
   # RED: Test
   def test_thread_local_isolation
     marble1 = RealityMarble.chant { expect(File, :exist?) { true } }
     marble2 = RealityMarble.chant { expect(File, :exist?) { false } }

     results = []
     t1 = Thread.new { marble1.activate { results << File.exist?('/any') } }
     t2 = Thread.new { marble2.activate { results << File.exist?('/any') } }

     t1.join; t2.join
     assert_includes results, true
     assert_includes results, false
   end

   # GREEN: Implementation
   module RealityMarble
     @mutex = Mutex.new

     def self.current_context
       Thread.current[:reality_marble_context]
     end

     def self.push_context(marble)
       @mutex.synchronize do
         ctx = Thread.current[:reality_marble_context] ||= Context.new
         ctx.push(marble)
       end
     end
   end
   ```

2. **Reference Counting**:
   ```ruby
   class Context
     def initialize
       @stack = []
       @redefined_methods = {}
     end

     def push(marble)
       if @stack.empty?
         redefine_all_methods(marble.expectations)
       end
       @stack.push(marble)
     end

     def pop
       @stack.pop
       if @stack.empty?
         restore_all_methods
       end
     end
   end
   ```

3. **Upfront Bulk Redefinition**:
   ```ruby
   def activate
     RealityMarble.push_context(self)
     begin
       yield
     ensure
       RealityMarble.pop_context
     end
   end
   ```

**Implementation files**:
- `lib/reality_marble/context.rb` (new)
- `lib/reality_marble/method_redefiner.rb` (new)
- `lib/reality_marble.rb` (major refactor)
- `test/reality_marble/context_test.rb` (new)
- `test/reality_marble/nested_activation_test.rb` (new)
- `test/reality_marble/thread_safety_test.rb` (new)

**Risk**: Large refactor, maintain backward compatibility with v0.1.0 API.

**Mitigation**: Feature flag: `RealityMarble.use_tracepoint = true` (default: false in v0.3.0)

#### 2.2 Performance Benchmarking

**Create benchmarks**:
```ruby
# test/benchmark/mock_overhead_bench.rb
require 'benchmark'

Benchmark.bmbm do |x|
  x.report("no mock") { 1000.times { File.exist?(__FILE__) } }

  x.report("reality_marble v0.1") do
    marble = RealityMarble.chant { expect(File, :exist?) { true } }
    marble.activate { 1000.times { File.exist?(__FILE__) } }
  end

  x.report("reality_marble v0.3 (案3.2)") do
    # Same but with TracePoint implementation
  end

  x.report("rspec-mocks") do
    allow(File).to receive(:exist?).and_return(true)
    1000.times { File.exist?(__FILE__) }
  end
end
```

**Coverage**: Not applicable (benchmark, not test)

### Phase 3: 案4 Research Project (NICE TO HAVE for v1.0.0)

**Priority: ⭐⭐ LOW (Research only)**

**Goal**: Prove feasibility of Prism AST transformation approach.

**User's note**: 案4 is a "fascinating research project but impractical for production". Implement as experimental feature only.

#### 3.1 Proof of Concept: AST Visitor

**Implementation**:
```ruby
# lib/reality_marble/prism/test_transformer.rb
require 'prism'

class TestMethodTransformer < Prism::Visitor
  def visit_def_node(node)
    return unless node.name.to_s.start_with?('test_')

    # Transform:
    # def test_foo
    #   system('git')
    # end

    # Into:
    # def test_foo
    #   __rm_ctx = RealityMarble.test_context(self); __rm_ctx.activate do
    #     system('git')
    #   end; ensure; __rm_ctx.teardown; end

    # Use one-liner injection to preserve line numbers
  end
end
```

**Test**:
```ruby
# test/reality_marble/prism/transformer_test.rb
def test_transforms_test_method
  input = <<~RUBY
    def test_example
      system('git')
      assert true
    end
  RUBY

  transformed = RealityMarble::Prism::TestTransformer.transform(input)

  assert_match(/RealityMarble.test_context/, transformed)
  # Verify line numbers preserved
end
```

#### 3.2 Source Map Registry

**Implementation**:
```ruby
# lib/reality_marble/prism/source_map.rb
class SourceMap
  def initialize
    @mappings = {}
  end

  def register(original_file, transformed_file, line_mappings)
    @mappings[transformed_file] = {
      original: original_file,
      lines: line_mappings # { transformed_line => original_line }
    }
  end

  def rewrite_backtrace(backtrace)
    backtrace.map do |line|
      # Rewrite "test_foo.rb:10" → "test_foo.rb:9" (original line)
    end
  end
end
```

#### 3.3 Require Hook Integration

**Implementation**:
```ruby
# lib/reality_marble/auto.rb
require 'reality_marble/prism/test_transformer'

module Kernel
  alias_method :__rm_original_require, :require

  def require(path)
    if path.match?(/_test\.rb$/)
      transformed = RealityMarble::Prism::TestTransformer.transform_file(path)
      eval(transformed, TOPLEVEL_BINDING, path)
    else
      __rm_original_require(path)
    end
  end
end
```

**User can enable**:
```ruby
# test/test_helper.rb
require 'reality_marble/auto' # ← Only addition

# All test files automatically transformed
```

**Risk**: Extremely complex, hard to debug, breaks editor support.

**Mitigation**: Document as "experimental", provide detailed troubleshooting guide.

---

## Design Decision Guide

### When to Use Which Design (案2 vs 案3.2 vs 案4)

**Use Current Implementation (v0.1.0 Method Redefinition)**:
- ✅ Simple use cases (picotorokko internal tests)
- ✅ Quick prototyping
- ✅ Learning/teaching Ruby metaprogramming
- ❌ Production gems with complex mocking needs

**Use 案3.2 (TracePoint + Upfront Redefinition)**:
- ✅ Production-ready public gem
- ✅ Thread-safety required
- ✅ Nested activation support needed
- ✅ Performance-critical applications
- ❌ Legacy Ruby < 3.3 support needed

**Use 案2 (Refinements + Guarded Dispatch)**:
- ✅ Maximum lexical scope safety
- ✅ Avoid global state pollution
- ✅ Educational: demonstrate Refinements power
- ❌ Production Code Boundary Problem (can't mock across files)
- ❌ Performance overhead (Thread-local checks on every call)

**Use 案4 (Prism AST Transformation)**:
- ✅ Research projects
- ✅ Ultimate transparency (zero mock setup code)
- ✅ Blog posts / conference talks
- ❌ Production use (too complex, breaks tooling)
- ❌ Editor support issues (LSP, debuggers)

### Recommended Path Forward

**For picotorokko project** (next session):
1. Implement Phase 1 features (call history, argument matching, exceptions)
2. Keep current architecture (simple method redefinition)
3. Add feature flag for 案3.2 migration later

**For public gem release**:
1. Complete Phase 1 (v0.2.0)
2. Migrate to 案3.2 architecture (v0.3.0)
3. Add 案4 as experimental opt-in feature (v1.0.0)

---

## Technical Debt and Known Issues

### Current Implementation Issues

#### Issue 1: C Extension Methods Restoration Fails

**Problem**:
```ruby
# File.exist? is implemented in C
original = File.method(:exist?)  # Returns #<Method: File.exist?>
original.unbind  # Raises TypeError: can't unbind C function
```

**Current workaround**: Store Method object, re-bind on restoration
```ruby
# lib/reality_marble.rb:94
target.define_method(method, original_method.unbind)  # ← FAILS for C methods
```

**Proper solution** (Phase 2):
- Use `alias_method` instead of `define_method`
- Or: Use TracePoint to intercept calls (案3.2)

**Test to add**:
```ruby
def test_restores_c_extension_methods
  marble = RealityMarble.chant { expect(File, :exist?) { false } }
  marble.activate { File.exist?('/any') }

  # Should not raise TypeError
  assert File.exist?(__FILE__)  # Original behavior restored
end
```

#### Issue 2: No Support for Block Arguments in Mocks

**Problem**:
```ruby
marble = RealityMarble.chant do
  expect(Array, :new).with(3) { |i| i * 2 }  # Block not captured
end
```

**Solution**: Capture block in call history
```ruby
class CallRecord
  attr_reader :args, :kwargs, :block

  def initialize(args:, kwargs:, block:)
    @args = args
    @kwargs = kwargs
    @block = block
  end
end
```

#### Issue 3: Coverage Gap in Branch Coverage (72.22%)

**Missing branches**:
- `elsif target.method_defined?(method)` (lib/reality_marble.rb:98)
- Instance method without original (edge case)

**Solution**: Add test for method that doesn't exist before mocking
```ruby
def test_mocks_nonexistent_method
  test_class = Class.new

  marble = RealityMarble.chant do
    expect(test_class, :new_method) { "mocked" }
  end

  marble.activate do
    assert_equal "mocked", test_class.new.new_method
  end

  # After activation, method should not exist
  refute_respond_to test_class.new, :new_method
end
```

---

## Next Session Handoff

### What to Start With

**Recommended first task** (1-2 hours):
1. Fix C extension method restoration issue (Issue 1 above)
2. Add test: `test_restores_c_extension_methods`
3. Use `alias_method` approach:
   ```ruby
   # Save original
   klass.singleton_class.alias_method(:"__rm_original_#{method}", method)

   # Restore
   klass.singleton_class.alias_method(method, :"__rm_original_#{method}")
   klass.singleton_class.remove_method(:"__rm_original_#{method}")
   ```

### Files to Focus On

**High priority** (Phase 1):
- `lib/reality_marble.rb` (core logic)
- `test/reality_marble/marble_test.rb` (existing tests)
- Create: `lib/reality_marble/call_record.rb`
- Create: `lib/reality_marble/expectation.rb`
- Create: `test/reality_marble/call_tracking_test.rb`

**Medium priority** (Phase 2):
- Create: `lib/reality_marble/context.rb`
- Create: `lib/reality_marble/method_redefiner.rb`

**Low priority** (Phase 3):
- Create: `lib/reality_marble/prism/` (experimental)

### Questions to Resolve

1. **API Design for Call History**:
   ```ruby
   # Option A: Method chaining
   marble.calls_to(File, :read).count
   marble.calls_to(File, :read).first.args

   # Option B: Hash-like access
   marble.calls[File][:read].count
   marble.calls[File][:read][0].args

   # User preference?
   ```

2. **Argument Matching DSL**:
   ```ruby
   # Option A: Separate expectation per matcher
   expect(File, :read).with('/specific').returns('A')
   expect(File, :read).with_any.returns('B')

   # Option B: Single expectation, multiple matchers
   expect(File, :read)
     .when(args: ['/specific']).returns('A')
     .when(args: :any).returns('B')

   # User preference?
   ```

3. **Migration Strategy to 案3.2**:
   - Big bang refactor (v0.3.0)?
   - Gradual (feature flag + deprecation period)?

### Git Status

**Branch**: `claude/explore-refinements-mock-gem-011CV16XH8TZmeY4jQVjxgW3`
**Last commit**: `80cfefb - feat: add reality_marble gem as independent gem structure`
**Status**: Rebased on latest `origin/main`, ready to merge

**To merge to main**:
```bash
git checkout main
git merge --no-ff claude/explore-refinements-mock-gem-011CV16XH8TZmeY4jQVjxgW3
git push origin main
```

---

## User's Final Words (Session Context)

> "reality_marble gem単体としてのTODOは何が残っていますか？
> reality_marbleは既存のRubyのmock/stubライブラリの実装に比べてどんな優位性がありますか？"

**User's mindset**:
- Honest evaluation: v0.1.0 is not competitive yet
- But: REALITY_MARBLE_TODO.md designs (案2/案3.2/案4) unlock unique value
- Killer feature: **Transparency** (案4)
- Core strength: **Lexical scope isolation** (案2/案3.2)
- Differentiator: **TYPE-MOON metaphor** (cultural appeal)

**User's expectations for next session**:
- Implement Phase 1 features (call history, argument matching, exceptions)
- Keep TDD discipline (Red → Green → RuboCop → Refactor → Commit)
- Maintain test coverage ≥ 75% line, ≥ 55% branch
- Document design decisions in this file

**User's long-term vision**:
- v0.2.0: Production-ready for picotorokko
- v0.3.0: Public gem release with 案3.2 architecture
- v1.0.0: 案4 as experimental feature, conference talk material

---

## References

- **Design document**: `REALITY_MARBLE_TODO.md` (2500+ lines, 案2/案3/案4 detailed specs)
- **User guide**: `lib/reality_marble/README.md`
- **Development guide**: `lib/reality_marble/CLAUDE.md`
- **Changelog**: `lib/reality_marble/CHANGELOG.md`

---

**Session end**: All changes committed, rebased on main, ready for next session.

がんばってピョン！チェケラッチョ！！
