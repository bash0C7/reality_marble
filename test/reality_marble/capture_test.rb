require "test_helper"

class CaptureTest < RealityMarbleTestCase
  def test_capture_option_passes_hash_to_block
    captured = {}

    RealityMarble.chant(capture: { data: captured }) do |cap|
      cap[:data][:count] = 42
    end

    assert_equal 42, captured[:count]
  end

  def test_capture_with_reference_mutation
    state = { value: 0 }

    RealityMarble.chant(capture: { state: state }) do |cap|
      cap[:state][:value] = 100
      cap[:state][:nested] = { key: "test" }
    end

    assert_equal 100, state[:value]
    assert_equal "test", state[:nested][:key]
  end

  def test_capture_multiple_variables
    counters = { a: 0, b: 0 }

    RealityMarble.chant(capture: { counters: counters }) do |cap|
      cap[:counters][:a] += 5
      cap[:counters][:b] += 10
    end

    assert_equal 5, counters[:a]
    assert_equal 10, counters[:b]
  end

  def test_chant_without_capture_no_block_param
    executed = false
    marble = RealityMarble.chant do
      executed = true
    end
    result = marble.activate { "result" }

    assert executed
    assert_equal "result", result
  end
end
