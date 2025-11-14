require_relative "../test_helper"

module RealityMarble
  class HelperTest < Test::Unit::TestCase
    # Test simple RealityMarble.mock helper
    def test_simple_mock_helper
      test_class = Class.new
      test_class.define_singleton_method(:greet) { |name| "Hello, #{name}!" }

      # Use simple mock helper
      RealityMarble.mock(test_class, :greet) { "Mocked!" }

      assert_equal "Mocked!", test_class.greet("World")
    end

    # Test mock helper with block that receives arguments
    def test_mock_helper_with_arguments
      test_class = Class.new
      test_class.define_singleton_method(:add) { |a, b| a + b }

      RealityMarble.mock(test_class, :add) do |a, b|
        "#{a} + #{b}"
      end

      assert_equal "5 + 3", test_class.add(5, 3)
    end

    # Test mock helper within chant/activate block for scoped usage
    def test_mock_helper_with_activate
      test_class = Class.new
      test_class.define_singleton_method(:value) { "original" }

      # Inside activate, mock is active
      marble = RealityMarble.chant do
        expect(test_class, :value) { "mocked" }
      end
      marble.activate do
        assert_equal "mocked", test_class.value
      end

      # Outside activate, original is restored
      assert_equal "original", test_class.value
    end

    # Cleanup after each test
    def teardown
      Context.reset_current
    end
  end
end
