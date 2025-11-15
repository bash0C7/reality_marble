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

  def test_nested_activation_with_same_method
    test_class = Class.new

    marble1 = RealityMarble.chant do
      test_class.define_singleton_method(:value) { "marble1" }
    end

    marble2 = RealityMarble.chant do
      test_class.define_singleton_method(:value) { "marble2" }
    end

    # Nested activation where both marbles modify the same method
    marble1.activate do
      assert_equal "marble1", test_class.value

      marble2.activate do
        assert_equal "marble2", test_class.value
      end

      # After marble2 cleanup, marble1's version should be restored
      assert_equal "marble1", test_class.value
    end

    # After both cleanup, method should not exist
    assert_raises(NoMethodError) { test_class.value }
  end

  def test_nested_activation_with_different_methods
    test_class = Class.new

    marble1 = RealityMarble.chant do
      test_class.define_singleton_method(:method_a) { "a" }
    end

    marble2 = RealityMarble.chant do
      test_class.define_singleton_method(:method_b) { "b" }
    end

    marble1.activate do
      assert_equal "a", test_class.method_a

      marble2.activate do
        assert_equal "b", test_class.method_b
      end

      # marble2's method should be removed after cleanup
      assert_raises(NoMethodError) { test_class.method_b }
      # marble1's method should still be available
      assert_equal "a", test_class.method_a
    end

    # After both cleanup, both methods should not exist
    assert_raises(NoMethodError) { test_class.method_a }
    assert_raises(NoMethodError) { test_class.method_b }
  end

  def test_applied_methods_tracking
    test_class = Class.new

    marble = RealityMarble.chant do
      test_class.define_singleton_method(:test_method) { "test" }
    end

    # After chant, applied_methods should be tracked
    # (chant applies then immediately cleans up, so @applied_methods will have been set)
    assert_respond_to marble, :instance_variable_get
    applied = marble.instance_variable_get(:@applied_methods)
    assert applied.is_a?(Set)

    # After activate, methods should be applied
    marble.activate do
      # Inside activate, method should be available
      assert_equal "test", test_class.test_method
    end

    # After activate, method should be removed
    assert_raises(NoMethodError) { test_class.test_method }
  end

  def test_only_parameter_restricts_method_collection
    target_class = Class.new
    other_class = Class.new

    marble = RealityMarble.chant(only: [target_class]) do
      target_class.define_singleton_method(:target_method) { "target" }
      other_class.define_singleton_method(:other_method) { "other" }
    end

    # Only target_class methods should be detected
    assert marble.defined_methods.key?([target_class.singleton_class, :target_method])
    assert !marble.defined_methods.key?([other_class.singleton_class, :other_method])
  end

  def test_only_parameter_with_multiple_classes
    class_a = Class.new
    class_b = Class.new
    class_c = Class.new

    marble = RealityMarble.chant(only: [class_a, class_b]) do
      class_a.define_singleton_method(:method_a) { "a" }
      class_b.define_singleton_method(:method_b) { "b" }
      class_c.define_singleton_method(:method_c) { "c" }
    end

    # Only class_a and class_b methods should be detected
    assert marble.defined_methods.key?([class_a.singleton_class, :method_a])
    assert marble.defined_methods.key?([class_b.singleton_class, :method_b])
    assert !marble.defined_methods.key?([class_c.singleton_class, :method_c])
  end

  def test_only_parameter_activates_correctly
    test_class = Class.new

    marble = RealityMarble.chant(only: [test_class]) do
      test_class.define_singleton_method(:value) { "mocked" }
    end

    marble.activate do
      assert_equal "mocked", test_class.value
    end

    assert_raises(NoMethodError) { test_class.value }
  end
end
