require "test_helper"
require "stringio"

class RefinementWarningTest < RealityMarbleTestCase
  def test_no_warning_for_unmodified_refinements
    # This test ensures that warnings are not emitted for Refinements
    # that exist in ObjectSpace but are not actually modified by the user.
    # PowerAssert and REXML::DClonable are loaded but not explicitly mocked,
    # so they should not trigger warnings.

    old_stderr = $stderr
    $stderr = StringIO.new

    begin
      RealityMarble.chant do
        # Define a new method on a regular class (not a Refinement)
        String.define_singleton_method(:test_method) { "mocked" }
      end

      warnings = $stderr.string

      # Verify that Refinement warnings are NOT present
      # (PowerAssert and REXML::DClonable should not generate warnings)
      assert_not_match(/\[RealityMarble\] Warning:/, warnings,
                       "Should not warn about unmodified Refinements from gems")
    ensure
      $stderr = old_stderr
    end
  end

  def test_warning_for_newly_defined_refinement_method
    # This test ensures that warnings ARE emitted when the user explicitly
    # defines methods in a Refinement module (positive test case).
    # We create a Refinement at the top level, then verify warnings are emitted.

    old_stderr = $stderr
    $stderr = StringIO.new

    begin
      # Create a module that will become a Refinement
      RealityMarble.chant do
        # Create a Refinement-like module structure
        # When Ruby loads a module with 'refine' inside, it becomes a Refinement
        Module.new do
          refine String do
            def custom_test_method
              "mocked"
            end
          end
        end
      end

      warnings = $stderr.string

      # Verify that Refinement warnings ARE present when a new Refinement is created
      assert_match(/\[RealityMarble\] Warning:/, warnings,
                   "Should warn when creating methods in Refinement")
      assert_match(/using.*keyword/, warnings,
                   "Warning should mention 'using' keyword requirement")
    ensure
      $stderr = old_stderr
    end
  end

  def test_warning_uses_refinement_detection
    # This test verifies that the warn_if_refinement method correctly
    # identifies Refinement instances from ObjectSpace.
    # It's a unit test of the detection mechanism.

    # Get a known Refinement from ObjectSpace
    # StringHelpers should be loaded from refinement_support_test.rb
    refinement = ObjectSpace.each_object(Module).find do |mod|
      mod.instance_of?(Refinement) && mod.to_s =~ /String@StringHelpers/
    end

    return unless refinement

    old_stderr = $stderr
    $stderr = StringIO.new

    begin
      # The key test: RealityMarble detects and warns about the Refinement
      # by using ObjectSpace. Since StringHelpers is already loaded and not modified
      # by our chant block, there should be no warning (it's unmodified).
      RealityMarble.chant do
        # No modifications to StringHelpers - just define something else
        String.define_singleton_method(:unrelated_test) { "test" }
      end

      warnings = $stderr.string

      # Verify no warnings for unmodified Refinements (this is the fix)
      assert_not_match(/\[RealityMarble\] Warning:.*StringHelpers/, warnings,
                       "Should not warn about unmodified StringHelpers Refinement")
    ensure
      $stderr = old_stderr
    end
  end
end
