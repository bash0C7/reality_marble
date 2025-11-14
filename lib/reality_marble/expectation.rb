module RealityMarble
  # Expectation: Define conditions and return values for mocked methods
  class Expectation
    attr_reader :target_class, :method_name, :matchers, :return_value, :block

    def initialize(target_class, method_name, &block)
      @target_class = target_class
      @method_name = method_name
      @matchers = []
      @return_value = nil
      @block = block
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

    # Set return value for this expectation
    #
    # @param value [Object] The value to return
    # @return [self]
    def returns(value)
      @return_value = value
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
      if @block
        @block.call(*args)
      else
        @return_value
      end
    end
  end
end
