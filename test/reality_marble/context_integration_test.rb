require_relative "../test_helper"

module RealityMarble
  class ContextIntegrationTest < Test::Unit::TestCase
    # Context singleton per thread
    def test_context_current_singleton
      ctx1 = Context.current
      ctx2 = Context.current
      assert_equal ctx1, ctx2
    end

    # Context push/pop manages stack
    def test_context_push_pop_stack
      marble = Marble.new
      ctx = Context.current

      assert ctx.empty?, "Context should start empty"

      ctx.push(marble)
      refute ctx.empty?, "Context should have marble after push"
      assert_equal 1, ctx.size

      ctx.pop
      assert ctx.empty?, "Context should be empty after pop"
    end

    # Reference counting: only first push triggers setup, only last pop triggers teardown
    def test_context_reference_counting
      marble1 = Marble.new
      marble2 = Marble.new
      ctx = Context.current

      # First push: triggers setup
      ctx.push(marble1)
      assert_equal 1, ctx.size

      # Second push: no additional setup
      ctx.push(marble2)
      assert_equal 2, ctx.size

      # First pop: no teardown yet
      ctx.pop
      assert_equal 1, ctx.size

      # Last pop: triggers teardown
      ctx.pop
      assert ctx.empty?
    end

    # Marble access from stack
    def test_context_access_marble_from_stack
      marble = Marble.new
      ctx = Context.current
      ctx.push(marble)

      assert_equal marble, ctx.stack.last

      ctx.pop
    end

    # Thread-local isolation
    def test_context_thread_local
      ctx_main = Context.current
      ctx_other = nil

      t = Thread.new do
        ctx_other = Context.current
      end

      t.join

      refute_equal ctx_main, ctx_other
    end

    # Edge case: Context ownership verification prevents cross-context mock calls
    def test_context_ownership_isolation
      marble = Marble.new
      ctx_main = Context.current

      # Activate marble in main thread
      ctx_main.push(marble)

      # Define expectation for a test method
      test_class = Class.new
      marble.expectations << Expectation.new(test_class, :test_method, -> { "mock result" })

      # Verify mock is set up
      ctx_main.backup_and_define_methods_for(marble.expectations)

      # Try to call mock from different context (separate thread)
      result_from_other = nil
      t = Thread.new do
        # Other thread has different Context instance
        refute_equal ctx_main, Context.current
        # Call test_method - should NOT execute mock due to context mismatch
        result_from_other = test_class.test_method
      end

      t.join
      assert_nil result_from_other, "Mock should not execute in different context"

      # Cleanup
      ctx_main.pop
    end

    # Edge case: Method restoration after deactivation
    def test_method_restoration_after_deactivation
      test_class = Class.new
      test_class.define_singleton_method(:original_method) { "original" }

      marble = Marble.new
      marble.expectations << Expectation.new(test_class, :original_method, -> { "mock" })
      ctx = Context.current

      # Activate marble
      ctx.push(marble)
      assert_equal "mock", test_class.original_method

      # Deactivate marble
      ctx.pop
      assert_equal "original", test_class.original_method
    end

    # Edge case: Nested marbles with same method
    def test_nested_marbles_same_method
      test_class = Class.new
      test_class.define_singleton_method(:shared_method) { "original" }

      marble1 = Marble.new
      marble1.expectations << Expectation.new(test_class, :shared_method, -> { "mock1" })

      marble2 = Marble.new
      marble2.expectations << Expectation.new(test_class, :shared_method, -> { "mock2" })

      ctx = Context.current

      # Push first marble
      ctx.push(marble1)
      assert_equal "mock1", test_class.shared_method

      # Push second marble - should use newer expectation
      ctx.push(marble2)
      assert_equal "mock2", test_class.shared_method

      # Pop second marble
      ctx.pop
      assert_equal "mock1", test_class.shared_method

      # Pop first marble
      ctx.pop
      assert_equal "original", test_class.shared_method
    end

    # Cleanup after each test
    # Note: Context cleanup is automatic via activate's ensure block,
    # but we must reset for isolation between tests
    def teardown
      Context.reset_current
    end
  end
end
