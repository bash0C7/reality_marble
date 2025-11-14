require "test_helper"

class NativeSyntaxTest < RealityMarbleTestCase
  def test_marble_tracks_defined_methods
    marble = RealityMarble.chant do
      # Placeholder for method definition detection
    end

    assert marble.defined_methods.is_a?(Hash)
    assert marble.defined_methods.empty?
  end

  def test_defined_methods_hash_structure
    marble = RealityMarble.chant

    assert_respond_to marble, :defined_methods
    assert_equal({}, marble.defined_methods)
  end

  def test_capture_with_class_reference
    captured = {}
    test_class = Class.new

    RealityMarble.chant(capture: { captured: captured, test_class: test_class }) do |cap|
      cap[:captured][:class_ref] = cap[:test_class]
    end

    assert_equal test_class, captured[:class_ref]
  end
end
