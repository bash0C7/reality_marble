module RealityMarble
  # Record of a single method call during mock activation
  class CallRecord
    attr_reader :args, :kwargs, :result, :exception

    def initialize(args: [], kwargs: {}, result: nil, exception: nil)
      @args = args
      @kwargs = kwargs
      @result = result
      @exception = exception
    end
  end
end
