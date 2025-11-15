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

  def test_modified_instance_method_restored
    test_class = Class.new do
      def original_method
        "original"
      end
    end

    original_obj = test_class.new

    marble = RealityMarble.chant do
      test_class.define_method(:original_method) do
        "mocked"
      end
    end

    # Before activate
    assert_equal "original", original_obj.original_method

    marble.activate do
      # During activate, mock is active
      assert_equal "mocked", original_obj.original_method
    end

    # After activate, original should be restored
    assert_equal "original", original_obj.original_method
  end

  def test_modified_singleton_method_restored
    test_class = Class.new
    test_class.define_singleton_method(:original_method) { "original" }

    marble = RealityMarble.chant do
      test_class.define_singleton_method(:original_method) { "mocked" }
    end

    # Before activate
    assert_equal "original", test_class.original_method

    marble.activate do
      # During activate, mock is active
      assert_equal "mocked", test_class.original_method
    end

    # After activate, original should be restored
    assert_equal "original", test_class.original_method
  end

  def test_nested_class_definition
    outer_class = Class.new
    inner_class = nil

    marble = RealityMarble.chant do
      outer_class.const_set(:InnerClass, Class.new)
      outer_class.const_get(:InnerClass).define_singleton_method(:nested_method) do
        "nested"
      end
      inner_class = outer_class.const_get(:InnerClass)
    end

    # Inner class method should be available during activate
    marble.activate do
      assert_equal "nested", inner_class.nested_method
    end

    # After activate, method should be removed
    assert_raises(NoMethodError) { inner_class.nested_method }
  end

  def test_method_with_inheritance
    parent_class = Class.new do
      def parent_method
        "parent"
      end
    end

    child_class = Class.new(parent_class)
    child_obj = child_class.new

    marble = RealityMarble.chant do
      child_class.define_method(:parent_method) do
        "mocked"
      end
    end

    marble.activate do
      # Mock overrides parent method
      assert_equal "mocked", child_obj.parent_method
    end

    # After activate, parent method should be restored
    assert_equal "parent", child_obj.parent_method
  end

  def test_method_with_super_keyword
    parent_class = Class.new do
      def calculate(num)
        num * 2
      end
    end

    child_class = Class.new(parent_class)
    child_obj = child_class.new

    marble = RealityMarble.chant do
      child_class.define_method(:calculate) do |num|
        super(num) + 10
      end
    end

    marble.activate do
      # Mocked method uses super
      assert_equal 20, child_obj.calculate(5)
    end

    # After activate, original should be restored
    # (no super, just original calculation)
    assert_equal 10, child_obj.calculate(5)
  end

  def test_context_stack_management
    # Verify that context stack properly tracks marbles
    test_class = Class.new

    marble = RealityMarble.chant do
      test_class.define_singleton_method(:test_method) { "test" }
    end

    ctx = RealityMarble::Context.current

    # Before activate
    assert ctx.empty?

    marble.activate do
      # During activate, marble is on stack
      assert_equal 1, ctx.size
      assert_equal marble, ctx.stack[0]
    end

    # After activate, stack should be empty
    assert ctx.empty?
  end

  def test_closure_support_without_capture
    counter = 0
    test_class = Class.new

    marble = RealityMarble.chant do
      test_class.define_method(:increment) do
        counter += 1
      end
    end

    marble.activate do
      obj = test_class.new
      obj.increment
      assert_equal 1, counter
    end
  end

  def test_multiple_modified_methods
    test_class = Class.new do
      def method_a
        "a"
      end

      def method_b
        "b"
      end
    end

    obj = test_class.new

    marble = RealityMarble.chant do
      test_class.define_method(:method_a) { "mocked_a" }
      test_class.define_method(:method_b) { "mocked_b" }
    end

    marble.activate do
      assert_equal "mocked_a", obj.method_a
      assert_equal "mocked_b", obj.method_b
    end

    # Both should be restored
    assert_equal "a", obj.method_a
    assert_equal "b", obj.method_b
  end

  def test_call_history_tracking
    test_class = Class.new

    marble = RealityMarble.chant do
      test_class.define_singleton_method(:track_call) do |arg|
        arg * 2
      end
    end

    marble.activate do
      test_class.track_call(5)
      test_class.track_call(10)
    end

    # Verify that calls were tracked
    assert_respond_to marble, :call_history
    assert marble.call_history.is_a?(Hash)
  end
end
