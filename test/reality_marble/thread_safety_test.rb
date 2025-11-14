require "test_helper"

class ThreadSafetyTest < RealityMarbleTestCase
  def test_thread_local_isolation
    # Each thread should have independent mock contexts
    marble1 = RealityMarble.chant do
      expect(File, :exist?) { true }
    end

    marble2 = RealityMarble.chant do
      expect(File, :exist?) { false }
    end

    results = []
    errors = []

    t1 = Thread.new do
      begin
        marble1.activate do
          results << File.exist?("/any")
        end
      rescue => e
        errors << e
      end
    end

    t2 = Thread.new do
      begin
        marble2.activate do
          results << File.exist?("/any")
        end
      rescue => e
        errors << e
      end
    end

    t1.join
    t2.join

    assert_empty errors, "Errors in threads: #{errors.inspect}"
    assert_includes results, true
    assert_includes results, false
  end

  def test_thread_local_doesnt_leak_to_other_threads
    # Thread 1 activates a marble, Thread 2 should see original behavior
    marble = RealityMarble.chant do
      expect(File, :exist?) { |_path| false }
    end

    thread1_result = nil
    thread2_result = nil
    original_behavior = File.exist?(__FILE__)

    t1 = Thread.new do
      marble.activate do
        # Inside marble context
        thread1_result = File.exist?(__FILE__)
      end
    end

    # Let t1 start before t2
    sleep 0.01

    t2 = Thread.new do
      # Outside marble context - should see original behavior
      thread2_result = File.exist?(__FILE__)
    end

    t1.join
    t2.join

    # Thread 1 saw the mock
    assert_equal false, thread1_result
    # Thread 2 saw the original
    assert_equal original_behavior, thread2_result
  end

  def test_nested_activation
    # Nested marbles should work correctly
    marble1 = RealityMarble.chant do
      expect(File, :exist?) { |_path| true }
    end

    marble2 = RealityMarble.chant do
      expect(File, :exist?) { |_path| false }
    end

    results = []

    marble1.activate do
      results << File.exist?("/file1")  # true

      marble2.activate do
        results << File.exist?("/file2")  # false
      end

      results << File.exist?("/file3")  # true again
    end

    assert_equal [true, false, true], results
  end

  def test_concurrent_different_methods
    # Two threads mocking different methods should not interfere
    marble1 = RealityMarble.chant do
      expect(File, :exist?) { false }
    end

    marble2 = RealityMarble.chant do
      expect(File, :read) { "mocked" }
    end

    results = {}
    errors = []

    t1 = Thread.new do
      begin
        marble1.activate do
          results[:t1_exist] = File.exist?(__FILE__)
        end
      rescue => e
        errors << e
      end
    end

    t2 = Thread.new do
      begin
        marble2.activate do
          results[:t2_read] = File.read(__FILE__)
        end
      rescue => e
        errors << e
      end
    end

    t1.join
    t2.join

    assert_empty errors
    assert_equal false, results[:t1_exist]
    assert_equal "mocked", results[:t2_read]
  end
end
