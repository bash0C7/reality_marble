require_relative "../test_helper"

module RealityMarble
  class ContextIntegrationTest < Test::Unit::TestCase
    # Context singleton per thread
    # TODO: [INFRASTRUCTURE-CONTEXT-DISPATCH] Stack overflow in mock dispatch when multiple tests run
    # Root cause: MockMethod defined on classes persists across teardowns, causing recursion
    # Temporary workaround: Mark tests as omit pending fix in next session
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

    # Cleanup after each test
    # Note: Context cleanup is automatic via activate's ensure block,
    # but we must reset for isolation between tests
    def teardown
      Context.reset_current
    end
  end
end
