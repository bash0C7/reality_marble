# Reality Marble v2.0: Development Tasks & Future Improvements

**Current Version**: v2.0 (Session 4 complete)

## 📊 Current Implementation Status

- ✅ **Modified & Deleted Methods**: Full restoration support
- ✅ **Nested Activation**: Multi-level marble support with proper isolation
- ✅ **Test Coverage**: 24 tests, 90.4% line / 66.67% branch coverage
- ✅ **Quality**: RuboCop clean, all tests passing
- ✅ **Code Clarity**: Complex nested activation logic properly documented

## 🎯 Planned Features (Phase 3+)

### Phase 3: Performance Tuning - ObjectSpace Optimization

**Goal**: Reduce method scanning overhead with `only:` parameter

**Proposed API**:
```ruby
# Without only: (current - scans all methods)
RealityMarble.chant do
  File.define_singleton_method(:exist?) { |p| p == "/mock" }
end

# With only: (future - scans only specified classes)
RealityMarble.chant(only: [File]) do
  File.define_singleton_method(:exist?) { |p| p == "/mock" }
end
```

**Implementation Plan**:
1. Add `only:` parameter to `Marble.new`
2. Modify `collect_all_methods` to respect `only:` filter
3. Add performance benchmark tests
4. Document performance characteristics

**Expected Impact**: 10-100x faster for targeted mocking (small number of classes)

### Phase 4: Advanced Features (Future)

- Refinements support (lexical scoping)
- TracePoint-based call tracking
- Module.prepend for method_added hook
- Optional lazy ObjectSpace scanning
