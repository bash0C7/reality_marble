require_relative "../test_helper"

module RealityMarble
  class EdgeCasesTest < Test::Unit::TestCase
    # Edge case: Empty marble with no expectations
    def test_empty_marble_activation
      marble = RealityMarble.chant
      # No expectations defined

      marble.activate do
        # Should activate without errors even with no expectations
        assert true
      end

      # Call history should be empty
      assert_empty marble.call_history.values.flatten
    end

    # Edge case: Marble reused multiple times
    def test_marble_reused_multiple_activations
      marble = RealityMarble.chant do
        expect(Array, :length) { 42 }
      end

      # First activation
      marble.activate do
        assert_equal 42, [].length
      end

      # Second activation - should work again
      marble.activate do
        assert_equal 42, [].length
      end

      # Call history should accumulate
      calls = marble.calls_for(Array, :length)
      assert_equal 2, calls.length
    end

    # Edge case: Deeply nested marbles
    def test_deeply_nested_marbles
      test_class = Class.new
      test_class.define_singleton_method(:value) { 0 }

      marbles = Array.new(5) do |i|
        RealityMarble.chant do
          expect(test_class, :value) { i }
        end
      end

      # Nest all marbles using lambda (no yield in lambda, pass block as arg)
      nest_marbles = lambda do |marbles_to_nest, depth = 0, &block|
        if depth >= marbles_to_nest.length
          block.call
        else
          marbles_to_nest[depth].activate do
            nest_marbles.call(marbles_to_nest, depth + 1, &block)
          end
        end
      end

      nest_marbles.call(marbles, 0) do
        # At deepest level, should use last marble (index 4)
        assert_equal 4, test_class.value
      end

      # All marbles should have been activated
      marbles.each_with_index do |m, i|
        calls = m.calls_for(test_class, :value)
        assert_equal 1, calls.length, "Marble #{i} should have been called"
      end
    end

    # Edge case: Mock on module (not just Class)
    def test_mock_on_module
      test_module = Module.new
      test_module.define_singleton_method(:module_method) { "original" }

      marble = RealityMarble.chant do
        expect(test_module, :module_method) { "mocked" }
      end

      marble.activate do
        assert_equal "mocked", test_module.module_method
      end

      assert_equal "original", test_module.module_method
    end

    # Edge case: Call history with many calls
    def test_large_call_history
      test_class = Class.new
      test_class.define_singleton_method(:process) { |x| x }

      marble = RealityMarble.chant do
        expect(test_class, :process) { |x| x * 2 }
      end

      marble.activate do
        # Make many calls
        100.times { |i| test_class.process(i) }
      end

      calls = marble.calls_for(test_class, :process)
      assert_equal 100, calls.length

      # Verify last call
      assert_equal 99, calls.last.args[0]
    end

    # Edge case: Exception during marble activation
    def test_exception_during_activation_restores
      test_class = Class.new
      test_class.define_singleton_method(:value) { "original" }

      marble = RealityMarble.chant do
        expect(test_class, :value) { "mocked" }
      end

      begin
        marble.activate do
          assert_equal "mocked", test_class.value
          raise "Test exception"
        end
      rescue RuntimeError
        # Expected
      end

      # Original should still be restored despite exception
      assert_equal "original", test_class.value
    end

    # Edge case: Marble with same method on different classes
    def test_multiple_classes_same_method
      class_a = Class.new
      class_b = Class.new

      class_a.define_singleton_method(:shared) { "a" }
      class_b.define_singleton_method(:shared) { "b" }

      marble = RealityMarble.chant do
        expect(class_a, :shared) { "mocked_a" }
        expect(class_b, :shared) { "mocked_b" }
      end

      marble.activate do
        assert_equal "mocked_a", class_a.shared
        assert_equal "mocked_b", class_b.shared
      end

      assert_equal "a", class_a.shared
      assert_equal "b", class_b.shared
    end

    # Edge case: Expectation with nil return value
    def test_expectation_returning_nil
      test_class = Class.new
      test_class.define_singleton_method(:nilish) { "not nil" }

      marble = RealityMarble.chant do
        expect(test_class, :nilish) { nil }
      end

      marble.activate do
        result = test_class.nilish
        assert_nil result
      end
    end

    # Edge case: Mock that returns different types
    def test_mock_returning_various_types
      test_class = Class.new
      test_class.define_singleton_method(:polymorphic) { "original" }

      marble = RealityMarble.chant do
        expect(test_class, :polymorphic) do |type|
          case type
          when :string
            "string value"
          when :number
            42
          when :array
            [1, 2, 3]
          when :hash
            { key: "value" }
          when :nil
            nil
          end
        end
      end

      marble.activate do
        assert_equal "string value", test_class.polymorphic(:string)
        assert_equal 42, test_class.polymorphic(:number)
        assert_equal [1, 2, 3], test_class.polymorphic(:array)
        assert_equal({ key: "value" }, test_class.polymorphic(:hash))
        assert_nil test_class.polymorphic(:nil)
      end
    end

    # Cleanup after each test
    def teardown
      Context.reset_current
    end
  end
end
