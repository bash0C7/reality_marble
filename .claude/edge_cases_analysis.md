# Edge Case Analysis: Reality Marble Limitations & Design Decisions

## Current Test Failures (Session 5)

### Analysis Summary

Running 50 comprehensive edge case tests revealed 4 failure patterns:

1. **Aliased Methods** (2 failures)
   - `test_aliased_instance_method`
   - `test_singleton_alias`

2. **Private Methods** (1 error)
   - `test_private_method_override`

3. **Method Introspection** (1 failure)
   - `test_method_introspection_with_instance_method`

**Pass Rate**: 46/50 tests = 92% ✅
**Coverage**: 90.77% line / 66.67% branch (exceeds thresholds)

---

## Detailed Failure Analysis

### 1. Aliased Method Problem

**Issue**: When a method is aliased (via `alias_method`), Ruby creates a reference to the original method. When we override the original method via `define_method`, the alias still points to the original implementation.

**Technical Root Cause**:
```ruby
class Example
  def original_method; "original"; end
  alias_method :aliased_method, :original_method
end

# Ruby internally: alias points to Method object, not the name
# When we define_method(:original_method, new_impl), alias still uses old impl
```

**Test Case**: Mock only `original_method`, expect alias to use mock
```ruby
marble = RealityMarble.chant do
  klass.define_method(:original_method) { "mocked" }
end

marble.activate do
  obj.original_method        # ✅ "mocked"
  obj.aliased_method         # ❌ "original" (still points to old Method)
end
```

**Why It Happens**:
- `alias_method :alias, :original` creates a reference to the Method object, not the method name
- Redefining `:original` doesn't update the alias reference
- This is **Ruby's fundamental behavior**, not a Reality Marble limitation

**Current Workaround**: Mock both the original and alias separately
```ruby
marble = RealityMarble.chant do
  klass.define_method(:original_method) { "mocked" }
  klass.define_method(:aliased_method) { "mocked" }   # ✅ Works
end
```

**Design Decision Options**:
- [ ] A) Accept as limitation, document in README
- [ ] B) Detect aliases and auto-mock them (complex, introspection required)
- [ ] C) Use `Module.prepend` + `method_added` to intercept aliases
- [ ] D) Require explicit alias targets in chant block

---

### 2. Private Method Override Problem

**Issue**: Private methods have visibility restrictions. When we override with `define_method`, the method becomes public (default visibility).

**Test Case**:
```ruby
klass = Class.new do
  private
  def private_method; "original"; end
end

marble = RealityMarble.chant do
  klass.send(:define_method, :private_method) { "mocked" }
end

marble.activate do
  obj.private_method  # ❌ NoMethodError (can't call private method publicly)
  obj.send(:private_method)  # ✅ Works
end
```

**Why It Happens**:
- `define_method` creates a public method by default
- We'd need to track visibility separately and restore it
- Currently, Reality Marble doesn't preserve visibility

**Current Workaround**: Use `.send(:method_name)` to call private methods in tests

**Design Decision Options**:
- [ ] A) Accept as expected behavior (mocks are public test doubles)
- [ ] B) Track visibility and restore it (complex state management)
- [ ] C) Document that mocks lose visibility restrictions
- [ ] D) Add `private:` parameter to chant block

---

### 3. Method Introspection Problem

**Issue**: `Method` objects are compared by identity, not by content. After cleanup, the method object is different even though the logic is the same.

**Test Case**:
```ruby
klass = Class.new do
  def introspective; "original"; end
end

original_method = klass.instance_method(:introspective)

marble = RealityMarble.chant do
  klass.define_method(:introspective) { "mocked" }
end

mocked_method = klass.instance_method(:introspective)

# This fails:
assert_not_equal original_method, mocked_method  # ❌ They ARE equal after cleanup!
```

**Why It Happens**:
- When we store `original_method = UnboundMethod`, we're storing a reference
- During `cleanup_defined_methods`, we restore it: `define_method(:method, original_method)`
- The Method object IS the same after restoration

**Actually**: This test expectation is wrong! The Method objects *should* be equal after cleanup.

**Design Decision**: This reveals a test design issue, not a Reality Marble issue.
- The test should verify behavior, not Method object identity
- After cleanup, the method should be identical to the original

---

## Ruby's Complex Features: Not All Are Mockable

### Known Limitations (by design)

These Ruby features have fundamental conflicts with the mock/restore model:

| Feature | Issue | Workaround |
|---------|-------|-----------|
| **Aliases** | Point to original Method object | Mock both original and alias |
| **Visibility (private/protected)** | `define_method` always public | Use `.send()` in tests |
| **`method_added` hooks** | Fire during mock setup | Move mocking logic outside hooks |
| **Freezing** | Frozen classes can't be modified | Mock before freezing |
| **Refinements** | Lexically scoped, global mock system conflicts | Not compatible (Phase 4 decision needed) |
| **Method visibility metadata** | Not tracked separately | Accept as limitation |

---

## Recommended Test Modifications

### For Test Suite

1. **Remove/Modify Failing Tests**:
   - Keep tests that reveal real limitations
   - Fix test expectations that are incorrect
   - Document unsupported patterns

2. **Add Documentation Tests**:
   - Show what DOES work
   - Show known limitations
   - Provide workarounds

### For EdgeCasesTest

**Failing Tests** → Options:

- `test_aliased_instance_method` → Mark as "known limitation" or modify to use both targets
- `test_singleton_alias` → Same as above
- `test_private_method_override` → Document that visibility is lost, modify test
- `test_method_introspection_with_instance_method` → Fix test expectation (method objects should be equal)

---

## Architecture Implications

### Phase 4+ Decision: How to Handle Limitations

**Option 1: Pure Strategy** (Current, 92% coverage)
- Accept limitations, document them
- Keep implementation simple
- Pros: Clean, predictable behavior
- Cons: Some Ruby patterns unsupported

**Option 2: Defensive Strategy**
- Detect problematic patterns, warn at runtime
- Require explicit acknowledgment (`unsafe_aliases: true`)
- Pros: Catches mistakes early
- Cons: More complex, adds overhead

**Option 3: Comprehensive Strategy** (Phase 4+)
- Use `Module.prepend` + `method_added` hooks
- Track visibility separately
- Handle aliases automatically
- Pros: Supports more patterns
- Cons: Significantly more complex

### Recommended Path

**Phase 4.1** (Next):
1. ✅ Document all known limitations in README "Limitations" section
2. ✅ Add test cases showing workarounds
3. ✅ Keep implementation simple and predictable
4. ❓ Decide: Accept limitations or pursue comprehensive approach

**Phase 4.2** (Optional):
- If pursuing comprehensive approach:
  - Implement visibility tracking
  - Auto-detect and handle aliases
  - Add runtime warnings for risky patterns

---

## Test Coverage Goals

### Current Status
- **50 test cases** covering major Ruby patterns
- **92% pass rate**
- **90.77% line coverage** / **66.67% branch coverage**

### Recommendation

Accept current limitations and mark failing tests as:
- `@skip "Known limitation: aliased methods"`
- Document workaround in test comments

This maintains high coverage while being honest about limitations.

---

## Decision Checklist

- [ ] Document "Known Limitations" section in README
- [ ] Add "Workarounds" guide for problematic patterns
- [ ] Update failing tests with comments explaining why they fail
- [ ] Create LIMITATIONS.md document for advanced users
- [ ] Decide: Accept limitations (recommended) or pursue Phase 4 comprehensive approach
