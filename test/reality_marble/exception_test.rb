require "test_helper"

class ExceptionTest < RealityMarbleTestCase
  def test_raises_exception
    marble = RealityMarble.chant do
      expect(File, :read).raises(Errno::ENOENT)
    end

    marble.activate do
      assert_raises(Errno::ENOENT) { File.read("/nonexistent") }
    end
  end

  def test_raises_with_message
    marble = RealityMarble.chant do
      expect(File, :read).raises(RuntimeError, "Custom error message")
    end

    marble.activate do
      error = assert_raises(RuntimeError) { File.read("/any") }
      assert_equal "Custom error message", error.message
    end
  end

  def test_raises_with_argument_matching
    marble = RealityMarble.chant do
      expect(File, :read).with("/forbidden").raises(Errno::EACCES)
      expect(File, :read).with("/missing").raises(Errno::ENOENT)
      expect(File, :read).with_any.returns("default content")
    end

    marble.activate do
      assert_raises(Errno::EACCES) { File.read("/forbidden") }
      assert_raises(Errno::ENOENT) { File.read("/missing") }
      assert_equal "default content", File.read("/other")
    end
  end

  def test_block_and_raises_mutation
    marble = RealityMarble.chant do
      expect(String, :length) { 999 }
    end

    marble.activate do
      assert_equal 999, "hello".length
    end
  end

  def test_raises_overrides_block
    marble = RealityMarble.chant do
      expect(File, :read) { "original" }.raises(StandardError)
    end

    marble.activate do
      assert_raises(StandardError) { File.read("/any") }
    end
  end
end
