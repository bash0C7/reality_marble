require_relative "../test_helper"

module RealityMarble
  class ExpectationDslTest < Test::Unit::TestCase
    # Test expectation DSL with .with().returns()
    def test_expectation_with_returns_dsl
      test_class = Class.new
      test_class.define_singleton_method(:divide) { |a, b| a / b }

      marble = RealityMarble.chant do
        expect(test_class, :divide)
          .with(10, 2)
          .returns(5)
      end
      marble.activate do
        assert_equal 5, test_class.divide(10, 2)
      end
    end

    # Test expectation DSL with sequence of returns
    def test_expectation_with_sequence_returns
      test_class = Class.new
      test_class.define_singleton_method(:counter) { 0 }

      marble = RealityMarble.chant do
        expect(test_class, :counter)
          .with_any
          .returns(1, 2, 3)
      end
      marble.activate do
        assert_equal 1, test_class.counter
        assert_equal 2, test_class.counter
        assert_equal 3, test_class.counter
      end
    end

    # Test expectation DSL with block
    def test_expectation_with_block_dsl
      test_class = Class.new
      test_class.define_singleton_method(:process) { |x| x * 2 }

      marble = RealityMarble.chant do
        expect(test_class, :process) do |x|
          "Processed: #{x}"
        end
      end
      marble.activate do
        assert_equal "Processed: 42", test_class.process(42)
      end
    end

    # Cleanup after each test
    def teardown
      Context.reset_current
    end
  end
end
