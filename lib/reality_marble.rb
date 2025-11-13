require_relative "reality_marble/version"

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

  # Reality Marble context for managing mocks/stubs
  class Marble
    attr_reader :expectations

    def initialize
      @expectations = []
    end

    # Define an expectation (mock/stub) for a method
    #
    # @param target_class [Class, Module] The class/module to mock
    # @param method_name [Symbol] The method name to mock
    # @param block [Proc] The mock implementation
    # @return [self]
    def expect(target_class, method_name, &block)
      @expectations << { target_class: target_class, method_name: method_name, block: block }
      self
    end

    # Activate this Reality Marble for the duration of the block
    #
    # @yield The test block to execute with mocks active
    # @return [Object] The result of the test block
    def activate
      # Store original methods
      originals = {}
      @expectations.each do |exp|
        klass = exp[:target_class]
        method = exp[:method_name]
        mock_proc = exp[:block]

        # Determine if method is instance method or singleton method
        is_singleton = klass.singleton_methods.include?(method)
        target = is_singleton ? klass.singleton_class : klass

        # Save original method
        if is_singleton
          original_method = klass.method(method) if klass.respond_to?(method)
        elsif klass.instance_methods.include?(method)
          original_method = klass.instance_method(method)
        end
        originals[[target, method, is_singleton]] = original_method

        # Redefine method
        if is_singleton
          klass.singleton_class.define_method(method) do |*args, **kwargs, &blk|
            mock_proc.call(*args, **kwargs, &blk)
          end
        else
          klass.define_method(method) do |*args, **kwargs, &blk|
            mock_proc.call(*args, **kwargs, &blk)
          end
        end
      end

      # Execute test block
      result = yield

      result
    ensure
      # Restore original methods
      originals.each do |(target, method, is_singleton), original_method|
        if original_method
          if is_singleton
            target.define_method(method, original_method.unbind)
          else
            target.define_method(method, original_method)
          end
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
