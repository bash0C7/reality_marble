require_relative "reality_marble/version"
require_relative "reality_marble/call_record"
require_relative "reality_marble/expectation"
require_relative "reality_marble/context"

# Reality Marble (固有結界): Next-generation mock/stub library for Ruby 3.4+
#
# Inspired by TYPE-MOON's metaphor, Reality Marble creates a temporary "reality"
# where method behaviors are overridden only within specific test scopes using
# Refinements, TracePoint, and metaprogramming.
#
# @example Basic usage
#   RealityMarble.chant do
#     expect(FileUtils, :rm_rf) { |path| puts "Mock: Would delete #{path}" }
#   end.activate do
#     FileUtils.rm_rf('/some/path')  # Calls mock instead
#   end
#
# @example Test::Unit integration
#   class MyTest < Test::Unit::TestCase
#     def test_file_operations
#       RealityMarble.chant do
#         expect(File, :exist?) { |path| path == '/mock/path' }
#       end.activate do
#         assert File.exist?('/mock/path')
#         refute File.exist?('/other/path')
#       end
#     end
#   end
module RealityMarble
  class Error < StandardError; end

  # Thread-local stack of active marbles (for nested activation support)
  def self.marble_stack
    Thread.current[:reality_marble_stack] ||= []
  end

  # Reality Marble context for managing mocks/stubs
  class Marble
    attr_reader :expectations, :call_history, :capture, :defined_methods

    def initialize(capture: nil)
      @expectations = []
      @call_history = Hash.new { |h, k| h[k] = [] }
      @capture = capture
      @defined_methods = {}
    end

    # Define an expectation (mock/stub) for a method
    #
    # @param target_class [Class, Module] The class/module to mock
    # @param method_name [Symbol] The method name to mock
    # @param block [Proc] The mock implementation (optional)
    # @return [Expectation]
    def expect(target_class, method_name, &)
      exp = Expectation.new(target_class, method_name, &)
      @expectations << exp
      exp
    end

    # Get call history for a specific method
    #
    # @param target_class [Class, Module] The class/module
    # @param method_name [Symbol] The method name
    # @return [Array<CallRecord>] List of call records
    def calls_for(target_class, method_name)
      @call_history[[target_class, method_name]]
    end

    # Activate this Reality Marble for the duration of the block
    #
    # @yield The test block to execute with mocks active
    # @return [Object] The result of the test block
    def activate
      # Push to thread-local context (handles backup/define/restore)
      ctx = Context.current
      ctx.push(self)

      # Execute test block
      result = yield

      result
    ensure
      ctx = Context.current
      ctx.pop
    end
  end

  # Start defining a new Reality Marble
  #
  # @param capture [Hash, nil] Variables to pass into the block
  # @yield Block for defining expectations (receives capture hash as parameter)
  # @return [Marble] The configured marble
  def self.chant(capture: nil, &block)
    marble = Marble.new(capture: capture)
    if block
      if capture
        marble.instance_exec(capture, &block)
      else
        marble.instance_eval(&block)
      end
    end
    marble
  end

  # Simple helper: Mock a single method (convenience method for common patterns)
  #
  # Activates immediately. Deactivation happens via Context.reset_current (usually in teardown).
  # Use this for inline mocking without chant/activate boilerplate.
  #
  # @param target_class [Class, Module] The class/module to mock
  # @param method_name [Symbol] The method name to mock
  # @yield Block for mock implementation (receives method arguments)
  # @return [Marble] The configured marble (for call history inspection if needed)
  #
  # @example
  #   RealityMarble.mock(File, :exist?) { |path| path == "/tmp/test" }
  #   assert File.exist?("/tmp/test")
  #   refute File.exist?("/other/path")
  def self.mock(target_class, method_name, &block)
    marble = chant do
      expect(target_class, method_name, &block)
    end
    ctx = Context.current
    ctx.push(marble)
    marble
  end
end
