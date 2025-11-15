require_relative "../test_helper"

class AliasDetectionTest < Test::Unit::TestCase
  # Test 1: Understand alias_method behavior
  def test_alias_method_creates_reference_not_copy
    test_class = Class.new do
      def original_method
        "original"
      end
      alias_method :aliased_method, :original_method
    end

    # Get UnboundMethod objects for both
    original_unbound = test_class.instance_method(:original_method)
    aliased_unbound = test_class.instance_method(:aliased_method)

    # In Ruby, these should be EQUAL because alias_method creates a reference
    assert_equal original_unbound, aliased_unbound,
                 "Aliased method should have same UnboundMethod as original"
  end

  # Test 2: Verify auto_mock_aliases is called during chant
  def test_auto_mock_aliases_auto_mocks_aliased_methods
    test_class = Class.new do
      def original_method
        "original"
      end
      alias_method :aliased_method, :original_method
    end

    # Mock the original
    marble = RealityMarble.chant(only: [test_class]) do
      test_class.define_method(:original_method) { "mocked" }
    end

    marble.activate do
      # Both should be mocked if auto_mock_aliases works
      instance = test_class.new
      assert_equal "mocked", instance.original_method
      # This is the key test - aliased method should also be mocked
      assert_equal "mocked", instance.aliased_method,
                   "Aliased method should also be mocked"
    end
  end

  # Test 3: Multiple aliases of same method
  def test_multiple_aliases_all_mocked
    test_class = Class.new do
      def base_method
        "base"
      end
      alias_method :alias1, :base_method
      alias_method :alias2, :base_method
      alias_method :alias3, :base_method
    end

    marble = RealityMarble.chant(only: [test_class]) do
      test_class.define_method(:base_method) { "mocked" }
    end

    marble.activate do
      instance = test_class.new
      assert_equal "mocked", instance.base_method
      assert_equal "mocked", instance.alias1
      assert_equal "mocked", instance.alias2
      assert_equal "mocked", instance.alias3
    end
  end

  # Test 4: Chained aliases
  def test_chained_aliases_all_mocked
    test_class = Class.new do
      def method_a
        "a"
      end
      alias_method :method_b, :method_a
      alias_method :method_c, :method_b
    end

    marble = RealityMarble.chant(only: [test_class]) do
      test_class.define_method(:method_a) { "mocked" }
    end

    marble.activate do
      instance = test_class.new
      assert_equal "mocked", instance.method_a
      assert_equal "mocked", instance.method_b
      assert_equal "mocked", instance.method_c
    end
  end
end
