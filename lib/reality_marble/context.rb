module RealityMarble
  # Context: Thread-local management of active marbles with reference counting and ownership verification
  #
  # Phase 3 Implementation (Context Ownership Tracking):
  # - Mock methods capture defining_context in closure
  # - Mock method verifies current_context == defining_context to prevent stack overflow
  # - Enables safe nested context activation without recursive mock calls
  class Context
    attr_reader :stack

    def initialize
      @stack = []
      @backed_up_methods = {}
    end

    # Get or create thread-local context singleton
    def self.current
      Thread.current[:reality_marble_context] ||= new
    end

    # Reset context for cleanup (testing)
    # Simply clears the context, assuming tests properly cleanup via activate's ensure
    def self.reset_current
      Thread.current[:reality_marble_context] = nil
    end

    # Check if stack is empty
    def empty?
      @stack.empty?
    end

    # Get current stack size
    def size
      @stack.size
    end

    # Push marble: triggers backup/define on first marble
    def push(marble)
      backup_and_define_methods_for(marble.expectations) if @stack.empty?
      @stack.push(marble)
    end

    # Pop marble: triggers restore on last marble
    def pop
      @stack.pop
      restore_all_methods if @stack.empty?
    end

    # Execute dispatch with call information (called from mock method closure)
    def execute_dispatch(call_info)
      matching_exp, matching_marble = find_matching_expectation(
        call_info[:stack], call_info[:klass], call_info[:method], call_info[:args]
      )
      record_call_in_stack(call_info[:stack], call_info[:klass], call_info[:method],
                           call_info[:args], call_info[:kwargs])
      execute_with_expectation(matching_exp, matching_marble, call_info)
    end

    private

    # Backup originals and define mocks for all expectations
    def backup_and_define_methods_for(expectations)
      expectations.each do |exp|
        klass = exp.target_class
        method = exp.method_name
        key = [klass, method]

        # Skip if already backed up (nested expectations for same method)
        next if @backed_up_methods[key]

        # Backup original
        is_singleton = klass.singleton_methods.include?(method)
        target = is_singleton ? klass.singleton_class : klass
        backup_name = :"__rm_original_#{method}"

        method_exists = if is_singleton
                          klass.respond_to?(method)
                        else
                          klass.instance_methods.include?(method)
                        end

        target.alias_method(backup_name, method) if method_exists

        @backed_up_methods[key] = {
          target: target,
          backup_name: backup_name,
          existed: method_exists,
          original_method: method
        }

        # Define mock that uses Context stack
        define_mock_method(target, method, klass)
      end
    end

    # Define the mock method that dispatches to active marbles
    def define_mock_method(target, method, klass)
      # Capture context to verify ownership (prevents stack overflow in nested contexts)
      stack = @stack
      defining_context = self

      target.define_method(method) do |*args, **kwargs, &blk|
        current_context = Context.current
        return if current_context != defining_context

        call_info = { stack: stack, klass: klass, method: method, args: args, kwargs: kwargs, blk: blk }
        defining_context.execute_dispatch(call_info)
      end
    end

    # Record method call in all active marbles
    def record_call_in_stack(stack, klass, method, args, kwargs)
      stack.each { |m| m.call_history[[klass, method]] << CallRecord.new(args: args, kwargs: kwargs) }
    end

    # Execute with matching expectation or block
    def execute_with_expectation(matching_exp, matching_marble, call_info)
      if matching_exp
        matching_exp.call_with(call_info[:args], marble: matching_marble)
      elsif (exp_with_block = find_expectation_with_block(call_info[:stack],
                                                          call_info[:klass],
                                                          call_info[:method]))
        exp_with_block.block&.call(*call_info[:args], **call_info[:kwargs], &call_info[:blk])
      end
    end

    # Find matching expectation from most recent marble
    def find_matching_expectation(stack, klass, method, args)
      matching_exp = nil
      matching_marble = nil

      stack.reverse_each do |marble|
        matching = marble.expectations.find do |e|
          e.target_class == klass && e.method_name == method && e.matches?(args)
        end
        next unless matching

        matching_exp = matching
        matching_marble = marble
        break
      end

      [matching_exp, matching_marble]
    end

    # Find expectation with block in most recent marble
    def find_expectation_with_block(stack, klass, method)
      stack.last&.expectations&.find { |e| e.target_class == klass && e.method_name == method && e.block }
    end

    # Restore all backed-up methods
    def restore_all_methods
      @backed_up_methods.each do |(_method_key, info)|
        target = info[:target]
        backup_name = info[:backup_name]
        method_existed = info[:existed]
        original_method = info[:original_method]

        if method_existed
          target.alias_method(original_method, backup_name)
          target.remove_method(backup_name)
        elsif target.method_defined?(original_method)
          target.undef_method(original_method)
        end
      end

      @backed_up_methods.clear
    end
  end
end
