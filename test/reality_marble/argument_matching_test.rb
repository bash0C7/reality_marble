require "test_helper"

class ArgumentMatchingTest < RealityMarbleTestCase
  def test_with_exact_arguments
    marble = RealityMarble.chant do
      expect(File, :exist?).with("/specific/path").returns(true)
      expect(File, :exist?).with_any.returns(false)
    end

    marble.activate do
      assert File.exist?("/specific/path")
      refute File.exist?("/other/path")
    end
  end

  def test_with_any_matches_all
    marble = RealityMarble.chant do
      expect(File, :read).with_any.returns("mock content")
    end

    marble.activate do
      assert_equal "mock content", File.read("/path1")
      assert_equal "mock content", File.read("/path2")
    end
  end

  def test_returns_sets_return_value
    marble = RealityMarble.chant do
      expect(String, :length).returns(999)
    end

    marble.activate do
      assert_equal 999, "hello".length
    end
  end

  def test_expectation_with_multiple_conditions
    marble = RealityMarble.chant do
      expect(File, :exist?).with("/first").returns(true)
      expect(File, :exist?).with("/second").returns(false)
      expect(File, :exist?).with_any.returns(nil)
    end

    marble.activate do
      assert_equal true, File.exist?("/first")
      assert_equal false, File.exist?("/second")
      assert_nil File.exist?("/third")
    end
  end

  def test_with_multiple_arguments
    marble = RealityMarble.chant do
      expect(File, :write).with("/path", "content").returns(7)
    end

    marble.activate do
      assert_equal 7, File.write("/path", "content")
      # Different args should still match if with_any is used
      assert_nil File.write("/other", "data")
    end
  end
end
