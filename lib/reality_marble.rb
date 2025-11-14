require_relative "reality_marble/version"
require_relative "reality_marble/call_record"
require_relative "reality_marble/context"

# Reality Marble (固有結界): Next-generation mock/stub library for Ruby 3.4+
#
# Inspired by TYPE-MOON's metaphor, Reality Marble creates a temporary "reality"
# where method behaviors are overridden only within specific test scopes.
#
# Uses a lazy method application pattern: methods defined during chant are
# detected via ObjectSpace, removed, then reapplied only during activate.
# This ensures perfect test isolation with zero leakage.
#
# @example Basic usage with native syntax
#   RealityMarble.chant do
#     FileUtils.define_singleton_method(:rm_rf) do |path|
#       puts "Mock: Would delete #{path}"
#     end
#   end.activate do
#     FileUtils.rm_rf('/some/path')  # Calls mock instead
#   end
#
# @example With variable capture (mruby/c style)
#   git_called = false
#   RealityMarble.chant(capture: {git_called: git_called}) do |cap|
#     Kernel.define_method(:system) do |cmd|
#       cap[:git_called] = true
#     end
#   end.activate do
#     system('git clone https://example.com/repo.git')
#   end
module RealityMarble
  class Error < StandardError; end

  # Thread-local stack of active marbles (for nested activation support)
  def self.marble_stack
    Thread.current[:reality_marble_stack] ||= []
  end

  # Reality Marble context for managing mocks/stubs
  class Marble
    attr_reader :call_history, :capture, :defined_methods

    def initialize(capture: nil)
      @call_history = Hash.new { |h, k| h[k] = [] }
      @capture = capture
      @defined_methods = {}
    end

    # Get call history for a specific method
    #
    # @param target_class [Class, Module] The class/module
    # @param method_name [Symbol] The method name
    # @return [Array<CallRecord>] List of call records
    def calls_for(target_class, method_name)
      @call_history[[target_class, method_name]]
    end

    # Store method definitions that were created during chant block
    # by comparing ObjectSpace before and after execution
    #
    # @param before_methods [Hash] Methods before chant block execution
    def store_defined_methods(before_methods)
      after_methods = collect_all_methods
      @defined_methods = diff_methods(before_methods, after_methods)
    end

    # Apply stored method definitions to their targets
    def apply_defined_methods
      @defined_methods.each do |key, method_obj|
        target, method_name = key
        target.define_method(method_name, method_obj) if method_obj
      end
    end

    # Remove the temporarily defined methods
    def cleanup_defined_methods
      @defined_methods.each_key do |key|
        target, method_name = key
        target.remove_method(method_name) if target.respond_to?(:remove_method)
      end
    end

    # Collect all instance and singleton methods from all modules and classes
    # Format: {[target, method_name] => method_object}
    def collect_all_methods
      methods_hash = {}
      ObjectSpace.each_object(Module) do |mod|
        # Collect instance methods
        mod.instance_methods(false).each do |method_name|
          methods_hash[[mod, method_name]] = mod.instance_method(method_name)
        end
        # Collect singleton methods
        mod.singleton_methods(false).each do |method_name|
          methods_hash[[mod.singleton_class, method_name]] = mod.singleton_class.instance_method(method_name)
        end
      end
      methods_hash
    end

    # Compute difference between two method snapshots
    def diff_methods(before, after)
      after.reject { |key, _| before.key?(key) }
    end

    # Activate this Reality Marble for the duration of the block
    #
    # @yield The test block to execute with mocks active
    # @return [Object] The result of the test block
    def activate
      # Apply defined methods before pushing context
      apply_defined_methods

      # Push to thread-local context (handles backup/define/restore)
      ctx = Context.current
      ctx.push(self)

      # Execute test block
      result = yield

      result
    ensure
      # Pop context
      ctx = Context.current
      ctx.pop

      # Clean up defined methods
      cleanup_defined_methods
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
      # Snapshot methods before block execution
      before_methods = marble.collect_all_methods

      # Execute block (may define new methods)
      if capture
        marble.instance_exec(capture, &block)
      else
        marble.instance_eval(&block)
      end

      # Store the methods that were defined
      marble.store_defined_methods(before_methods)

      # Immediately remove the defined methods so they're only active during activate
      marble.cleanup_defined_methods
    end
    marble
  end
end
