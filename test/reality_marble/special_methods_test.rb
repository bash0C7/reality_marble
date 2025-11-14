require_relative "../test_helper"

module RealityMarble
  class SpecialMethodsTest < Test::Unit::TestCase
    # Test backtick (`) method mocking
    def test_backtick_method_mocking
      test_class = Class.new
      test_class.define_singleton_method(:`) { |cmd| "real: #{cmd}" }

      marble = Marble.new
      marble.expectations << Expectation.new(test_class, :`) { "mocked" }
      ctx = Context.current

      # Activate marble
      ctx.push(marble)
      assert_equal "mocked", test_class.`("test command")

      # Deactivate marble
      ctx.pop
      assert_equal "real: test command", test_class.`("test command")
    end

    # Test bracket access ([]) method mocking
    def test_bracket_access_method_mocking
      test_class = Class.new
      test_class.define_singleton_method(:[]) { |idx| "real[#{idx}]" }

      marble = Marble.new
      marble.expectations << Expectation.new(test_class, :[]) { "mocked" }
      ctx = Context.current

      # Activate marble
      ctx.push(marble)
      assert_equal "mocked", test_class.[](0)

      # Deactivate marble
      ctx.pop
      assert_equal "real[0]", test_class.[](0)
    end

    # Test bracket assign ([]= ) method mocking
    def test_bracket_assign_method_mocking
      test_class = Class.new
      test_class.define_singleton_method(:[]=) { |idx, val| "real[#{idx}]=#{val}" }

      marble = Marble.new
      marble.expectations << Expectation.new(test_class, :[]=) { "mocked" }
      ctx = Context.current

      # Activate marble
      ctx.push(marble)
      result = test_class.[]=(0, "value")
      assert_equal "mocked", result

      # Deactivate marble
      ctx.pop
      result = test_class.[]=(0, "value")
      assert_equal "real[0]=value", result
    end

    # Cleanup after each test
    def teardown
      Context.reset_current
    end
  end
end
