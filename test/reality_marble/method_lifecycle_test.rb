require "test_helper"

class MethodLifecycleTest < RealityMarbleTestCase
  def test_singleton_method_applied_in_activate
    test_class = Class.new

    marble = RealityMarble.chant do
      test_class.define_singleton_method(:greet) do |name|
        "Hello, #{name}"
      end
    end

    # Before activate, method should NOT be defined
    assert_raises(NoMethodError) { test_class.greet("World") }

    # During activate, method should be available
    marble.activate do
      assert_equal "Hello, World", test_class.greet("World")
    end

    # After activate, method should be removed
    assert_raises(NoMethodError) { test_class.greet("World") }
  end

  def test_instance_method_applied_in_activate
    test_class = Class.new
    obj = test_class.new

    marble = RealityMarble.chant do
      test_class.define_method(:calculate) do |x, y|
        x + y
      end
    end

    # Before activate
    assert_raises(NoMethodError) { obj.calculate(5, 3) }

    # During activate
    marble.activate do
      assert_equal 8, obj.calculate(5, 3)
    end

    # After activate
    assert_raises(NoMethodError) { obj.calculate(5, 3) }
  end

  def test_multiple_methods_lifecycle
    test_class = Class.new

    marble = RealityMarble.chant do
      test_class.define_singleton_method(:add) do |a, b|
        a + b
      end
      test_class.define_singleton_method(:multiply) do |a, b|
        a * b
      end
    end

    marble.activate do
      assert_equal 15, test_class.add(10, 5)
      assert_equal 50, test_class.multiply(10, 5)
    end

    assert_raises(NoMethodError) { test_class.add(10, 5) }
    assert_raises(NoMethodError) { test_class.multiply(10, 5) }
  end

  def test_activate_returns_block_result_with_methods_active
    test_class = Class.new

    marble = RealityMarble.chant do
      test_class.define_singleton_method(:value) { 42 }
    end

    result = marble.activate do
      test_class.value * 2
    end

    assert_equal 84, result
  end

  def test_overriding_existing_method
    existing_class = File

    marble = RealityMarble.chant do
      existing_class.define_singleton_method(:exist?) do |_path|
        "MOCKED"
      end
    end

    original_result = existing_class.exist?(__FILE__)

    marble.activate do
      # Mock is active
      assert_equal "MOCKED", existing_class.exist?("any_path")
    end

    # Original should be restored
    assert_equal original_result, existing_class.exist?(__FILE__)
  end
end
