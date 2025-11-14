require "test_helper"

class CallTrackingTest < RealityMarbleTestCase
  def test_tracks_call_history
    marble = RealityMarble.chant do
      expect(File, :read)
    end

    marble.activate do
      File.read(__FILE__)
      File.read(__FILE__)
    end

    assert_equal 2, marble.calls_for(File, :read).count
  end

  def test_records_call_arguments
    marble = RealityMarble.chant do
      expect(File, :exist?) { |_path| true }
    end

    marble.activate do
      File.exist?("/path1")
      File.exist?("/path2")
    end

    calls = marble.calls_for(File, :exist?)
    assert_equal 2, calls.count
    assert_equal "/path1", calls[0].args[0]
    assert_equal "/path2", calls[1].args[0]
  end

  def test_call_record_has_metadata
    marble = RealityMarble.chant do
      expect(String, :upcase)
    end

    marble.activate do
      "hello".upcase
    end

    calls = marble.calls_for(String, :upcase)
    assert_equal 1, calls.count

    call = calls.first
    assert_instance_of RealityMarble::CallRecord, call
    assert_equal [], call.args
    assert_equal({}, call.kwargs)
  end

  def test_returns_empty_array_for_unmocked_method
    marble = RealityMarble.chant do
      expect(File, :exist?)
    end

    marble.activate do
      File.exist?(__FILE__)
    end

    assert_equal 0, marble.calls_for(File, :read).count
  end

  def test_returns_empty_array_before_activation
    marble = RealityMarble.chant do
      expect(File, :exist?)
    end

    assert_equal 0, marble.calls_for(File, :exist?).count
  end
end
