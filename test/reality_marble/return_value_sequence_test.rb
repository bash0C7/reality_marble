require_relative "../test_helper"

module RealityMarble
  class ReturnValueSequenceTest < Test::Unit::TestCase
    # Single sequence with multiple values
    def test_returns_sequence_basic
      marble = RealityMarble.chant do
        expect(Array, :shift).returns("first", "second", "third")
      end

      marble.activate do
        arr = [1, 2, 3]
        assert_equal "first", arr.shift
        assert_equal "second", arr.shift
        assert_equal "third", arr.shift
      end
    end

    # Sequence exhausted: returns last value
    def test_returns_sequence_exhausted_returns_last
      marble = RealityMarble.chant do
        expect(Array, :shift).returns("first", "second")
      end

      marble.activate do
        arr = [1, 2, 3, 4]
        assert_equal "first", arr.shift
        assert_equal "second", arr.shift
        assert_equal "second", arr.shift # Returns last value
        assert_equal "second", arr.shift
      end
    end

    # Sequence with single value (backward compatibility)
    def test_returns_sequence_single_value
      marble = RealityMarble.chant do
        expect(Array, :shift).returns("only")
      end

      marble.activate do
        arr = [1, 2]
        assert_equal "only", arr.shift
        assert_equal "only", arr.shift
      end
    end

    # Sequence per expectation (not shared across marbles)
    def test_returns_sequence_per_expectation
      marble1 = RealityMarble.chant do
        expect(Array, :shift).returns("m1_first", "m1_second")
      end

      marble2 = RealityMarble.chant do
        expect(Array, :shift).returns("m2_first", "m2_second")
      end

      marble1.activate do
        arr1 = [1, 2, 3]
        assert_equal "m1_first", arr1.shift
        assert_equal "m1_second", arr1.shift

        marble2.activate do
          arr2 = [1, 2, 3]
          assert_equal "m2_first", arr2.shift
          assert_equal "m2_second", arr2.shift
        end

        # marble1 sequence continues
        assert_equal "m1_second", arr1.shift
      end
    end

    # Sequence with with() matcher
    def test_returns_sequence_with_matcher
      marble = RealityMarble.chant do
        expect(Array, :at).with(0).returns("a", "b")
        expect(Array, :at).with(1).returns("x", "y")
      end

      marble.activate do
        arr = [100, 200]
        assert_equal "a", arr.at(0)
        assert_equal "b", arr.at(0)
        assert_equal "b", arr.at(0)

        assert_equal "x", arr.at(1)
        assert_equal "y", arr.at(1)
        assert_equal "y", arr.at(1)
      end
    end

    # Sequence with different types
    def test_returns_sequence_mixed_types
      marble = RealityMarble.chant do
        expect(Array, :first).returns(1, "two", nil, false)
      end

      marble.activate do
        arr = [1, 2, 3]
        assert_equal 1, arr.first
        assert_equal "two", arr.first
        assert_nil arr.first
        assert_equal false, arr.first
        assert_equal false, arr.first
      end
    end

    # Sequence is exhausted correctly (no error, just returns last)
    def test_returns_sequence_no_error_on_exhaustion
      marble = RealityMarble.chant do
        expect(Array, :pop).returns(true, false)
      end

      marble.activate do
        arr = [1, 2, 3]
        assert_equal true, arr.pop
        assert_equal false, arr.pop
        # No error, just continues with last value
        assert_equal false, arr.pop
        assert_equal false, arr.pop
      end
    end

    # Sequence with raises (raises takes precedence, not sequence)
    def test_returns_sequence_ignores_raises
      marble = RealityMarble.chant do
        expect(Hash, :fetch).raises(KeyError)
      end

      marble.activate do
        assert_raises(KeyError) { { a: 1 }.fetch(:b) }
        assert_raises(KeyError) { { a: 1 }.fetch(:b) }
      end
    end

    # Sequence with block takes precedence
    def test_returns_sequence_ignores_block
      marble = RealityMarble.chant do
        expect(Array, :first) { |_arr| "block_value" }
      end

      marble.activate do
        assert_equal "block_value", [1, 2, 3].first
        assert_equal "block_value", [1, 2, 3].first
      end
    end
  end

  def teardown
    RealityMarble::Context.reset_current
  end
end
