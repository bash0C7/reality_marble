require_relative "../test_helper"

module RealityMarble
  class ThreadSafetyStressTest < Test::Unit::TestCase
    # Test concurrent nested marbles across multiple threads
    def test_concurrent_nested_marbles
      test_class = Class.new
      test_class.define_singleton_method(:shared_method) { "original" }

      # Create test expectations
      marbles = Array.new(3) do |i|
        m = Marble.new
        m.expectations << Expectation.new(test_class, :shared_method) { "marble#{i}" }
        m
      end

      results = {}
      errors = []

      # Run threads with nested marbles
      threads = Array.new(3) do |thread_id|
        Thread.new do
          ctx = Context.current
          begin
            # Each thread activates its own marble
            ctx.push(marbles[thread_id])

            # Nested activation in same thread
            if thread_id < 2
              other_marble = Marble.new
              other_marble.expectations << Expectation.new(test_class, :shared_method) { "nested#{thread_id}" }
              ctx.push(other_marble)

              # Should use nested expectation
              results["#{thread_id}_nested"] = test_class.shared_method

              ctx.pop
            end

            # Should use thread's marble
            results["#{thread_id}_outer"] = test_class.shared_method

            ctx.pop
          rescue StandardError => e
            errors << "Thread #{thread_id}: #{e.message}"
          end
        end
      end

      threads.each(&:join)

      # Verify no errors
      assert_empty errors, "No thread errors: #{errors.join(", ")}"

      # Verify correct mock results (thread isolation)
      assert_equal "marble0", results["0_outer"], "Thread 0 outer should use marble0"
      assert_equal "nested0", results["0_nested"], "Thread 0 nested should use nested0"
      assert_equal "marble1", results["1_outer"], "Thread 1 outer should use marble1"
      assert_equal "nested1", results["1_nested"], "Thread 1 nested should use nested1"
      assert_equal "marble2", results["2_outer"], "Thread 2 outer should use marble2"
    end

    # Cleanup after each test
    def teardown
      Context.reset_current
    end
  end
end
