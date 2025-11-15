module RealityMarble
  # Record of a single method call during mock activation
  #
  # %a{rbs: class CallRecord}
  class CallRecord
    # : () -> Array[untyped]
    attr_reader :args

    # : () -> Hash[untyped, untyped]
    attr_reader :kwargs

    # : () -> untyped
    attr_reader :result

    # : () -> Exception | nil
    attr_reader :exception

    # Initialize a new call record
    #
    # : (args: Array[untyped], kwargs: Hash[untyped, untyped], result: untyped, exception: Exception | nil) -> void
    def initialize(args: [], kwargs: {}, result: nil, exception: nil)
      @args = args
      @kwargs = kwargs
      @result = result
      @exception = exception
    end
  end
end
