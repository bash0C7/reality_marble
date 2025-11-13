require "test_helper"

class MarbleTest < RealityMarbleTestCase
  def test_chant_creates_marble
    marble = RealityMarble.chant
    assert_instance_of RealityMarble::Marble, marble
  end

  def test_expect_adds_expectation
    marble = RealityMarble.chant
    marble.expect(File, :exist?) { |_path| true }
    assert_equal 1, marble.expectations.size
  end

  def test_activate_executes_block
    executed = false
    marble = RealityMarble.chant
    marble.activate { executed = true }
    assert executed
  end

  def test_mock_overrides_method
    marble = RealityMarble.chant do
      expect(File, :exist?) { |path| path == "/mock/path" }
    end

    marble.activate do
      assert File.exist?("/mock/path")
      refute File.exist?("/other/path")
    end
  end

  def test_original_method_restored_after_activate
    # File.exist? は組み込みメソッドなので、再定義後も元に戻ることを確認
    original_behavior = File.exist?(__FILE__) # このファイルは存在する

    marble = RealityMarble.chant do
      expect(File, :exist?) { |_path| false }
    end

    marble.activate do
      refute File.exist?(__FILE__) # モック中はfalse
    end

    # 元に戻っていることを確認
    assert_equal original_behavior, File.exist?(__FILE__)
  end

  def test_multiple_expectations
    marble = RealityMarble.chant do
      expect(File, :exist?) { |path| path.start_with?("/mock") }
      expect(File, :read) { |path| "Mock content of #{path}" }
    end

    marble.activate do
      assert File.exist?("/mock/file.txt")
      refute File.exist?("/real/file.txt")
      assert_equal "Mock content of /mock/file.txt", File.read("/mock/file.txt")
    end
  end

  def test_activate_returns_block_result
    marble = RealityMarble.chant
    result = marble.activate { "test_result" }
    assert_equal "test_result", result
  end

  def test_instance_method_mocking
    # Test instance method mocking (not singleton method)
    test_class = Class.new do
      def greet(name)
        "Hello, #{name}"
      end
    end

    obj = test_class.new
    marble = RealityMarble.chant do
      expect(test_class, :greet) { |name| "Mock: Hi, #{name}" }
    end

    marble.activate do
      assert_equal "Mock: Hi, Alice", obj.greet("Alice")
    end

    # Verify restoration
    assert_equal "Hello, Bob", obj.greet("Bob")
  end

  def test_chant_with_block
    marble = RealityMarble.chant do
      expect(File, :exist?) { |_path| true }
    end
    assert_equal 1, marble.expectations.size
  end

  def test_chant_without_block
    marble = RealityMarble.chant
    assert_equal 0, marble.expectations.size
  end
end
