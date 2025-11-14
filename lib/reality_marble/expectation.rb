module RealityMarble
  # Expectation: Define conditions and return values for mocked methods
  class Expectation
    attr_reader :target_class, :method_name, :matchers, :return_value, :block, :exception

    def initialize(target_class, method_name, &block)
      @target_class = target_class
      @method_name = method_name
      @matchers = []
      @return_value = nil
      @return_sequence = []
      @sequence_index = 0
      @block = block
      @exception = nil
    end

    # Match against exact arguments
    #
    # @param args [Array] Arguments to match
    # @return [self]
    def with(*args)
      @matchers << { type: :exact, args: args }
      self
    end

    # Match against any arguments
    #
    # @return [self]
    def with_any
      @matchers << { type: :any }
      self
    end

    # Set return value(s) for this expectation
    #
    # @param values [Object] One or more values to return in sequence
    # @return [self]
    def returns(*values)
      if values.size == 1
        @return_value = values.first
        @return_sequence = []
      else
        @return_sequence = values
        @return_value = nil
        @sequence_index = 0
      end
      self
    end

    # Set exception to raise for this expectation
    #
    # @param exception_class [Class] The exception class to raise
    # @param message [String] Optional exception message
    # @return [self]
    def raises(exception_class, message = nil)
      @exception = { class: exception_class, message: message }
      self
    end

    # Check if given arguments match any of the matchers
    #
    # @param args [Array] Arguments to test
    # @return [Boolean]
    def matches?(args)
      return true if @matchers.empty?

      @matchers.any? do |matcher|
        case matcher[:type]
        when :exact
          matcher[:args] == args
        when :any
          true
        end
      end
    end

    # Get the return value for this expectation
    #
    # @param args [Array] Arguments (used to select matching return value)
    # @return [Object]
    def call_with(args)
      if @exception
        raise @exception[:class], @exception[:message] if @exception[:message]

        raise @exception[:class]
      elsif @block
        @block.call(*args)
      elsif @return_sequence.any?
        # Return sequence value, or last value if exhausted
        value = @return_sequence[@sequence_index]
        @sequence_index = [@sequence_index + 1, @return_sequence.size - 1].min
        value
      else
        @return_value
      end
    end
  end
end
