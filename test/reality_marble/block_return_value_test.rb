require_relative "../test_helper"

module RealityMarble
  class BlockReturnValueTest < Test::Unit::TestCase
    # Block with call count parameter
    def test_block_with_call_count
      marble = RealityMarble.chant do
        expect(Array, :shift) do |*_args, count: 0|
          count.zero? ? "first" : "second"
        end
      end

      marble.activate do
        arr = [1, 2]
        assert_equal "first", arr.shift
        assert_equal "second", arr.shift
        assert_equal "second", arr.shift
      end
    end

    # Block with marble context via block parameter
    def test_block_with_marble_context
      marble = RealityMarble.chant do
        expect(Array, :shift) do |*_args, marble: nil|
          if marble
            history = marble.calls_for(Array, :shift)
            history.length >= 4 ? "done" : "item"
          else
            "no_context"
          end
        end
      end

      marble.activate do
        arr = [1, 2, 3, 4, 5]
        assert_equal "item", arr.shift
        assert_equal "item", arr.shift
        assert_equal "item", arr.shift
        assert_equal "done", arr.shift
        assert_equal "done", arr.shift
      end
    end

    # Block without keyword parameters (backward compatibility)
    def test_block_without_keyword_parameters
      marble = RealityMarble.chant do
        expect(Array, :pop) do |*args|
          args.empty? ? "empty" : args.first
        end
      end

      marble.activate do
        arr = [1, 2]
        assert_equal "empty", arr.pop
        assert_equal "empty", arr.pop
      end
    end

    # Count resets per new marble activation
    def test_block_count_resets_per_marble
      marble1 = RealityMarble.chant do
        expect(Array, :shift) do |count: 0|
          "m1_call_#{count}"
        end
      end

      marble2 = RealityMarble.chant do
        expect(Array, :shift) do |count: 0|
          "m2_call_#{count}"
        end
      end

      marble1.activate do
        arr1 = [1, 2]
        assert_equal "m1_call_0", arr1.shift
        assert_equal "m1_call_1", arr1.shift

        marble2.activate do
          arr2 = [1, 2]
          assert_equal "m2_call_0", arr2.shift
          assert_equal "m2_call_1", arr2.shift
        end

        # marble1 count continues
        assert_equal "m1_call_2", arr1.shift
      end
    end
  end
end
