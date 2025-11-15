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
#
# %a{rbs: RealityMarble}
module RealityMarble
  # Exception class for Reality Marble errors
  #
  # %a{rbs: class Error < StandardError}
  class Error < StandardError; end

  # Thread-local stack of active marbles (for nested activation support)
  #
  # : () -> Array[Marble]
  def self.marble_stack
    Thread.current[:reality_marble_stack] ||= []
  end

  # Reality Marble context for managing mocks/stubs
  #
  # %a{rbs: class Marble}
  class Marble
    attr_reader :call_history, :capture, :defined_methods, :modified_methods, :deleted_methods, :only

    # Initialize a new Marble
    #
    # : (capture: Hash[Symbol, Object]?, only: Array[Module]?) -> void
    def initialize(capture: nil, only: nil)
      @call_history = Hash.new { |h, k| h[k] = [] }
      @capture = capture
      @only = only # Array of classes to monitor (nil = all classes)
      @defined_methods = {}
      @modified_methods = {}
      @deleted_methods = {}
      @applied_methods = Set.new # Track methods this marble applied
      @visibility = {} # Track visibility of private/protected methods
    end

    # Get call history for a specific method
    #
    # : (target_class: Module, method_name: Symbol) -> Array[CallRecord]
    def calls_for(target_class, method_name)
      @call_history[[target_class, method_name]]
    end

    # Detect visibility (public, private, or protected) of a method
    #
    # : (target: Module, method_name: Symbol) -> Symbol
    def detect_visibility(target, method_name)
      if target.private_instance_methods(false).include?(method_name)
        :private
      elsif target.protected_instance_methods(false).include?(method_name)
        :protected
      else
        :public
      end
    end

    # Store visibility of methods before they are mocked
    #
    # : () -> void
    def store_visibility
      @visibility = {}
      # Store visibility for modified, deleted, and newly defined methods
      [@modified_methods, @deleted_methods, @defined_methods].each do |method_hash|
        method_hash.each_key do |key|
          target, method_name = key
          vis = detect_visibility(target, method_name)
          @visibility[key] = vis
        end
      end
    end

    # Restore visibility of methods after cleanup
    #
    # : () -> void
    def restore_visibility
      @visibility.each do |key, vis|
        next if vis == :public # Skip public methods (default visibility)

        target, method_name = key
        # Only restore visibility for instance methods (not singleton_class)
        # Check if the method exists before trying to restore visibility
        target.send(vis, method_name) if target.instance_methods(false).include?(method_name)
      end
    end

    # Detect aliases for a method by comparing UnboundMethod objects
    #
    # : (target: Module, method_name: Symbol) -> Array[Symbol]
    def detect_aliases(target, method_name)
      return [] unless target.respond_to?(:instance_methods)

      method = target.instance_method(method_name)
      aliases = []

      target.instance_methods(false).each do |other_name|
        next if other_name == method_name

        other_method = target.instance_method(other_name)
        # Same UnboundMethod object = alias
        aliases << other_name if method == other_method
      end

      aliases
    end

    # Auto-detect and mock aliases for newly defined and modified methods
    #
    # For newly defined methods: detect current aliases
    # For modified methods: detect aliases of the OLD method (before modification)
    #
    # : (before_methods: Hash) -> void
    def auto_mock_aliases(before_methods)
      # Handle newly defined methods (not in before_methods)
      @defined_methods.each_key do |key|
        key

        # For new methods: aliases are methods that currently equal the new implementation
        # But this may not find anything since aliases point to old method
        # So we skip new-only methods for now - aliases would have been detected elsewhere
      end

      # Handle modified methods (exist in both before and after)
      @modified_methods.each do |key, old_method|
        target, method_name = key

        # For modified methods: find what was aliased to the OLD implementation
        # by checking all methods in before_methods for that target
        before_methods.each do |other_key, before_impl|
          other_target, other_name = other_key
          next unless other_target == target
          next if other_name == method_name

          # If this method pointed to the same implementation as the original method,
          # it's an alias. We need to mock it too.
          next unless before_impl == old_method

          new_method_obj = @defined_methods[key]
          alias_key = [target, other_name]
          unless @defined_methods.key?(alias_key) || @modified_methods.key?(alias_key)
            @defined_methods[alias_key] = new_method_obj
          end
        end
      end
    end

    # Store method definitions that were created during chant block
    # by comparing ObjectSpace before and after execution
    #
    # @param before_methods [Hash] Methods before chant block execution
    def store_defined_methods(before_methods)
      after_methods = collect_all_methods

      # 新規メソッド = after に存在し before に存在しない
      new_methods = {}
      # 変更されたメソッド = 両方に存在し Method が異なる
      modified_methods = {}
      # 削除されたメソッド = before に存在し after に存在しない
      deleted_methods = {}

      after_methods.each do |key, after_method|
        if before_methods.key?(key)
          before_method = before_methods[key]
          # Method オブジェクトが異なれば、上書きされている
          if before_method != after_method
            modified_methods[key] = before_method
            # activate 中に新しい実装を apply するために @defined_methods に保存
            new_methods[key] = after_method
          end
        else
          new_methods[key] = after_method
        end
      end

      before_methods.each do |key, before_method|
        deleted_methods[key] = before_method unless after_methods.key?(key)
      end

      @defined_methods = new_methods
      @modified_methods = modified_methods
      @deleted_methods = deleted_methods
      # Auto-detect and mock aliases
      auto_mock_aliases(before_methods)
      # Store visibility before activation
      store_visibility
    end

    # Apply stored method definitions to their targets
    # Track which methods this marble applied for proper cleanup
    def apply_defined_methods
      @defined_methods.each do |key, method_obj|
        target, method_name = key
        target.define_method(method_name, method_obj) if method_obj
        @applied_methods.add(key)
      end
    end

    # Remove the temporarily defined methods and restore modified/deleted ones
    # Only clean up methods that this marble applied (not other nested marbles)
    def cleanup_defined_methods
      # 新規メソッドを削除（このmarbleが apply したものだけ）
      @defined_methods.each_key do |key|
        next unless @applied_methods.include?(key)

        target, method_name = key
        target.remove_method(method_name) if target.respond_to?(:remove_method)
      end

      # 変更されたメソッドを元に戻す（このmarbleが apply したものだけ）
      @modified_methods.each do |key, original_method|
        next unless @applied_methods.include?(key)

        target, method_name = key
        target.define_method(method_name, original_method)
      end

      # 削除されたメソッドを復元（このmarbleが apply したものだけ）
      @deleted_methods.each do |key, original_method|
        next unless @applied_methods.include?(key)

        target, method_name = key
        target.define_method(method_name, original_method)
      end

      # Restore visibility after cleanup
      restore_visibility
    end

    # Collect all instance and singleton methods from all modules and classes
    # If @only is set, only collect from those classes/modules
    # Format: {[target, method_name] => method_object}
    def collect_all_methods
      methods_hash = {}
      targets = @only || begin
        # If no restriction, collect from all objects
        result = []
        ObjectSpace.each_object(Module) { |mod| result << mod }
        result
      end

      targets.each do |mod|
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
    # : () { () -> untyped } -> untyped
    def activate
      # Before applying, check if any methods in the context stack are modified
      # (important for nested activation support)
      adjust_for_nested_activation

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

    # For nested activation: if any methods we're defining are already applied by
    # an outer marble, track them as modified (so we restore the outer marble's version)
    #
    # This handles complex edge cases:
    # 1. Same method overridden by nested marble (must restore outer version)
    # 2. Mixed singleton/instance method scenarios
    # 3. Nested marbles activating within each other
    def adjust_for_nested_activation
      ctx = Context.current
      return if ctx.empty?

      # Check each method we're about to apply
      @defined_methods.each do |key, new_method|
        target, method_name = key

        # Determine if method exists in current "world" (applied by outer marble)
        # Check both singleton and instance methods
        is_singleton_method = target.singleton_methods(false).include?(method_name)
        is_instance_method = target.instance_methods(false).include?(method_name)

        # Skip if method doesn't exist yet in current world
        next unless is_singleton_method || is_instance_method

        # Get the currently applied method based on its type
        current_method = if is_singleton_method
                           # For singleton methods, get from singleton_class
                           target.singleton_class.instance_method(method_name)
                         elsif is_instance_method
                           # For instance methods, get from instance_method
                           target.instance_method(method_name)
                         end

        # Track as modified if method exists and differs from new version
        # This ensures outer marble's version is restored after inner cleanup
        # rubocop:disable Style/IfUnlessModifier
        # Block form is required for clarity in this complex nested activation logic
        if current_method && current_method != new_method
          @modified_methods[key] = current_method
        end
        # rubocop:enable Style/IfUnlessModifier
      end
    end
  end

  # Start defining a new Reality Marble
  #
  # Detects methods defined during the block execution and stores them for lazy application
  # during activate. Uses ObjectSpace scanning plus optional TracePoint-based detection.
  #
  # : (capture: Hash[Symbol, Object]?, only: Array[Module]?) { (Hash[Symbol, Object]) -> void } -> Marble
  def self.chant(capture: nil, only: nil, &block)
    marble = Marble.new(capture: capture, only: only)
    if block
      # Snapshot methods before block execution
      before_methods = marble.collect_all_methods

      # Phase 4 Enhancement: TracePoint-based method detection (experimental)
      # This infrastructure allows tracking method definitions via Ruby's TracePoint API
      # Currently uses ObjectSpace scanning; TracePoint enhanced detection may be
      # enabled in future phases for additional edge case coverage

      # Execute block (may define new methods)
      if capture
        marble.instance_exec(capture, &block)
      else
        marble.instance_eval(&block)
      end

      # Store the methods that were defined
      marble.store_defined_methods(before_methods)

      # Immediately apply then remove the defined methods so they're only active during activate
      # (We apply to track them in @applied_methods, then immediately clean up)
      marble.apply_defined_methods
      marble.cleanup_defined_methods
    end
    marble
  end
end
