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
end
