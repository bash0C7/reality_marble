require_relative "../test_helper"

module RealityMarble
  class WarningTest < Test::Unit::TestCase
    # Test warning when mocking non-existent method
    def test_warning_for_nonexistent_method
      test_class = Class.new
      # Do NOT define original_method on test_class

      marble = Marble.new
      marble.expectations << Expectation.new(test_class, :nonexistent) { "mocked" }
      ctx = Context.current

      # Capture warnings (warn outputs to stderr)
      stderr_capture = StringIO.new
      old_stderr = $stderr
      $stderr = stderr_capture

      begin
        # Activate marble - should warn about missing original
        ctx.push(marble)

        # Verify warning was printed
        warning_output = stderr_capture.string
        assert_match(/nonexistent/, warning_output, "Should warn about nonexistent method")
        assert_match(/Mocking non-existent/, warning_output, "Should mention mocking non-existent")

        # Cleanup
        ctx.pop
      ensure
        $stderr = old_stderr
      end
    end

    # Cleanup after each test
    def teardown
      Context.reset_current
    end
  end
end
