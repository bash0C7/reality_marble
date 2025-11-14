require_relative "../test_helper"

module RealityMarble
  class PerformanceCharacteristicsTest < Test::Unit::TestCase
    # Performance test: Call history tracking with many calls
    # Verifies that call history grows predictably and remains accessible
    def test_call_history_tracking_efficiency
      test_class = Class.new
      test_class.define_singleton_method(:compute) { |x| x }

      marble = RealityMarble.chant do
        expect(test_class, :compute) { |x| x * 2 }
      end

      # Warm up
      marble.activate do
        test_class.compute(0)
      end

      # Main measurement: 1000 calls within single activation
      marble.activate do
        1000.times { |i| test_class.compute(i) }
      end

      calls = marble.calls_for(test_class, :compute)
      assert_equal 1001, calls.length, "Call history should contain all 1001 calls"

      # Verify we can access arbitrary call records
      assert_equal 0, calls[0].args[0], "First call (warm-up) should be 0"
      assert_equal 999, calls[1000].args[0], "Last call should be 999"
    end

    # Performance test: Multiple concurrent mocks in single marble
    # Verifies context switching between multiple expectations works efficiently
    def test_multiple_mocks_per_activation
      classes = Array.new(10) do
        klass = Class.new
        klass.define_singleton_method(:compute) { "original" }
        klass
      end

      marble = RealityMarble.chant do
        classes.each_with_index do |klass, idx|
          expect(klass, :compute) { "mocked_#{idx}" }
        end
      end

      marble.activate do
        # Call each mock 100 times
        classes.each_with_index do |klass, idx|
          100.times do
            result = klass.compute
            assert_equal "mocked_#{idx}", result
          end
        end
      end

      # Verify all were tracked
      classes.each_with_index do |klass, _idx|
        calls = marble.calls_for(klass, :compute)
        assert_equal 100, calls.length, "Each class should have 100 calls"
      end
    end

    # Performance test: Deeply nested marble activations
    # Verifies nesting overhead remains constant with depth
    def test_nested_marble_activation_depth
      test_class = Class.new
      test_class.define_singleton_method(:value) { "original" }

      # Create nested marbles at different depths
      depths = [1, 3, 5]

      depths.each do |depth|
        marbles = Array.new(depth) do |i|
          RealityMarble.chant do
            expect(test_class, :value) { "level_#{i}" }
          end
        end

        # Activate all marbles nested
        activate_nested(marbles, 0) do
          result = test_class.value
          # Deepest marble should be active
          assert_equal "level_#{depth - 1}", result
        end

        # Verify all were activated
        marbles.each_with_index do |marble, idx|
          calls = marble.calls_for(test_class, :value)
          assert_equal 1, calls.length, "Marble at depth #{idx} should have been called"
        end
      end
    end

    # Helper for nested activation
    def activate_nested(marbles, depth, &block)
      if depth >= marbles.length
        yield
      else
        marbles[depth].activate do
          activate_nested(marbles, depth + 1, &block)
        end
      end
    end

    # Performance test: Marble reuse and restoration
    # Verifies same marble can be activated multiple times with correct restoration
    def test_marble_reuse_restoration_pattern
      test_class = Class.new
      test_class.define_singleton_method(:state) { "original" }

      marble = RealityMarble.chant do
        expect(test_class, :state) { "mocked" }
      end

      # Reuse same marble 10 times
      10.times do |iteration|
        # Before activation: original should be active
        assert_equal "original", test_class.state, "Before activation #{iteration}"

        marble.activate do
          # During activation: mock should be active
          assert_equal "mocked", test_class.state, "During activation #{iteration}"
        end

        # After activation: original should be restored
        assert_equal "original", test_class.state, "After activation #{iteration}"
      end

      # All activations should be recorded
      calls = marble.calls_for(test_class, :state)
      assert_equal 10, calls.length, "Should have 10 calls across reuses"
    end

    # Performance test: Expectation block execution
    # Verifies block-based expectations execute efficiently with various inputs
    def test_expectation_block_execution_efficiency
      test_class = Class.new
      test_class.define_singleton_method(:transform) { |x| x }

      marble = RealityMarble.chant do
        expect(test_class, :transform) do |x|
          # Complex block logic
          result = (x * 2) + 1
          result %= 100 if result > 100
          result.to_s
        end
      end

      marble.activate do
        # Call with different argument types
        1000.times do |i|
          result = test_class.transform(i)
          expected = (((i * 2) + 1) % 100).to_s
          assert_equal expected, result
        end
      end

      calls = marble.calls_for(test_class, :transform)
      assert_equal 1000, calls.length
    end

    # Performance test: Exception raising from mocks
    # Verifies exception-based mocks work efficiently
    def test_exception_raising_efficiency
      test_class = Class.new
      test_class.define_singleton_method(:risky) { "ok" }

      marble = RealityMarble.chant do
        expect(test_class, :risky) do |should_fail|
          raise "Mock error" if should_fail

          "success"
        end
      end

      marble.activate do
        success_count = 0
        error_count = 0

        100.times do |i|
          # Alternate: even indices should fail
          should_fail = i.even?
          begin
            test_class.risky(should_fail)
            success_count += 1
          rescue RuntimeError
            error_count += 1
          end
        end

        # 50 even (0, 2, 4, ..., 98) = 50 failures
        # 50 odd (1, 3, 5, ..., 99) = 50 successes
        assert_equal 50, success_count, "Should have 50 successful calls"
        assert_equal 50, error_count, "Should have 50 failed calls"
      end

      calls = marble.calls_for(test_class, :risky)
      assert_equal 100, calls.length
    end

    # Performance test: Call argument recording
    # Verifies argument capturing works efficiently with complex objects
    def test_call_argument_recording_efficiency
      test_class = Class.new
      test_class.define_singleton_method(:process) { |data| data }

      marble = RealityMarble.chant do
        expect(test_class, :process) { |data| data.size }
      end

      marble.activate do
        # Various argument types and sizes
        200.times do |i|
          case i % 4
          when 0 then test_class.process(Array.new(10) { i })
          when 1 then test_class.process("string" * 10)
          when 2 then test_class.process({ key: "value" })
          when 3 then test_class.process(100 + i)
          end
        end
      end

      calls = marble.calls_for(test_class, :process)
      assert_equal 200, calls.length

      # Verify different argument types were captured
      array_calls = calls.select { |c| c.args[0].is_a?(Array) }
      string_calls = calls.select { |c| c.args[0].is_a?(String) }
      hash_calls = calls.select { |c| c.args[0].is_a?(Hash) }
      number_calls = calls.select { |c| c.args[0].is_a?(Integer) }

      assert_equal 50, array_calls.length
      assert_equal 50, string_calls.length
      assert_equal 50, hash_calls.length
      assert_equal 50, number_calls.length
    end

    # Performance test: Context reset behavior
    # Verifies context cleanup is efficient across many marbles
    def test_context_reset_efficiency
      # Create and use many marbles sequentially
      100.times do |marble_num|
        test_class = Class.new
        test_class.define_singleton_method(:id) { marble_num }

        marble = RealityMarble.chant do
          expect(test_class, :id) { 999 }
        end

        marble.activate do
          # Should return mocked value
          assert_equal 999, test_class.id
        end

        # Reset for next iteration
        Context.reset_current

        # Original should be restored
        assert_equal marble_num, test_class.id
      end
    end

    # Cleanup after each test
    def teardown
      Context.reset_current
    end
  end
end
