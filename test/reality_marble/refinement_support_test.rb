require_relative '../test_helper'

# Define refinements at the top level (outside test class)
module StringHelpers
  refine String do
    def shout
      upcase + '!!!'
    end

    def whisper
      downcase + '...'
    end
  end
end

module IntegerHelpers
  refine Integer do
    def double
      self * 2
    end
  end
end

class RefinementSupportTest < Test::Unit::TestCase

  # Test 1: Refinement modules are detectable via ObjectSpace
  def test_refinement_module_detection_via_objectspace
    # Refinement module should be in ObjectSpace
    refinement = ObjectSpace.each_object(Module).find do |mod|
      mod.to_s =~ /refinement:String@StringHelpers/
    end

    assert_not_nil refinement, 'Refinement module should be detectable via ObjectSpace'
    assert_equal 'Refinement', refinement.class.name
    assert refinement.instance_methods(false).include?(:shout)
    assert refinement.instance_methods(false).include?(:whisper)
  end

  # Test 2: Refinement methods are UnboundMethod objects
  def test_refinement_method_introspection
    refinement = ObjectSpace.each_object(Module).find do |mod|
      mod.to_s =~ /refinement:String@StringHelpers/
    end

    shout_method = refinement.instance_method(:shout)
    assert_kind_of UnboundMethod, shout_method
    assert_equal :shout, shout_method.name
  end

  # Test 3: Refinement module structure is consistent
  def test_refinement_module_consistency
    # Both StringHelpers and IntegerHelpers should have corresponding Refinements
    string_refinement = ObjectSpace.each_object(Module).find do |mod|
      mod.to_s =~ /refinement:String@StringHelpers/
    end

    integer_refinement = ObjectSpace.each_object(Module).find do |mod|
      mod.to_s =~ /refinement:Integer@IntegerHelpers/
    end

    assert_not_nil string_refinement
    assert_not_nil integer_refinement
    assert_equal 'Refinement', string_refinement.class.name
    assert_equal 'Refinement', integer_refinement.class.name
  end

  # Test 4: Refinement method list is correct
  def test_refinement_methods_list
    string_refinement = ObjectSpace.each_object(Module).find do |mod|
      mod.to_s =~ /refinement:String@StringHelpers/
    end

    methods = string_refinement.instance_methods(false)
    assert methods.include?(:shout)
    assert methods.include?(:whisper)
  end

end

