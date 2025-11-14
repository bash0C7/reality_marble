require_relative "reality_marble/version"
require_relative "reality_marble/call_record"
require_relative "reality_marble/expectation"

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

  # Global registry for tracking mock depth per method (for nested activation)
  @mock_depth_counter = Hash.new { |h, k| h[k] = 0 }
  @mock_depth_mutex = Mutex.new

  def self.increment_mock_depth(klass, method)
    @mock_depth_mutex.synchronize do
      @mock_depth_counter[[klass, method]] += 1
    end
  end

  def self.decrement_mock_depth(klass, method)
    @mock_depth_mutex.synchronize do
      @mock_depth_counter[[klass, method]] -= 1
    end
  end

  def self.mock_depth(klass, method)
    @mock_depth_mutex.synchronize do
      @mock_depth_counter[[klass, method]]
    end
  end

  # Reality Marble context for managing mocks/stubs
  class Marble
    attr_reader :expectations, :call_history

    def initialize
      @expectations = []
      @call_history = Hash.new { |h, k| h[k] = [] }
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
      originals = backup_and_mock_expectations

      # Execute test block
      result = yield

      result
    ensure
      restore_original_methods(originals)
    end

    private

    def backup_and_mock_expectations
      originals = {}
      @expectations.each do |exp|
        klass = exp.target_class
        method = exp.method_name

        # Only create backup on first activation for this method
        depth = RealityMarble.mock_depth(klass, method)
        if depth.zero?
          target, backup_name, method_exists = setup_backup_first_time(exp)
          originals[[target, method, backup_name]] = method_exists
        end

        RealityMarble.increment_mock_depth(klass, method)
        setup_mock(exp, method)
      end
      originals
    end

    def setup_backup_first_time(exp)
      klass = exp.target_class
      method = exp.method_name
      is_singleton = klass.singleton_methods.include?(method)
      target = is_singleton ? klass.singleton_class : klass
      backup_name = :"__rm_original_#{method}"

      method_exists = if is_singleton
                        klass.respond_to?(method)
                      else
                        klass.instance_methods.include?(method)
                      end

      target.alias_method(backup_name, method) if method_exists

      [target, backup_name, method_exists]
    end

    def setup_mock(exp, method)
      klass = exp.target_class
      is_singleton = klass.singleton_methods.include?(method)
      call_history = @call_history
      expectations = @expectations

      if is_singleton
        klass.singleton_class.define_method(method) do |*args, **kwargs, &blk|
          call_history[[klass, method]] << CallRecord.new(args: args, kwargs: kwargs)
          # Find matching expectation
          matching = expectations.find { |e| e.target_class == klass && e.method_name == method && e.matches?(args) }
          if matching
            matching.call_with(args)
          elsif exp.block
            exp.block.call(*args, **kwargs, &blk)
          end
        end
      else
        klass.define_method(method) do |*args, **kwargs, &blk|
          call_history[[klass, method]] << CallRecord.new(args: args, kwargs: kwargs)
          # Find matching expectation
          matching = expectations.find { |e| e.target_class == klass && e.method_name == method && e.matches?(args) }
          if matching
            matching.call_with(args)
          elsif exp.block
            exp.block.call(*args, **kwargs, &blk)
          end
        end
      end
    end

    def restore_original_methods(originals)
      originals.each do |(target, method, backup_name), method_existed|
        # Get the class from the target (singleton_class -> class)
        klass = target.is_a?(Class) && target.singleton_class == target ? target : method

        # Find the original class from expectations
        exp = @expectations.find { |e| e.method_name == method }
        klass = exp.target_class if exp

        # Only restore when depth reaches zero
        RealityMarble.decrement_mock_depth(klass, method)
        depth = RealityMarble.mock_depth(klass, method)

        next unless depth.zero?

        if method_existed
          target.alias_method(method, backup_name)
          target.remove_method(backup_name)
        elsif target.method_defined?(method)
          target.undef_method(method)
        end
      end
    end
  end

  # Start defining a new Reality Marble
  #
  # @yield Block for defining expectations
  # @return [Marble] The configured marble
  def self.chant(&block)
    marble = Marble.new
    marble.instance_eval(&block) if block
    marble
  end
end
