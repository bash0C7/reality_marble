module RealityMarble
  # Context: Thread-local management of active marbles with stack support
  #
  # Simplified context for the new native syntax API. The context now only
  # manages the stack of active marbles. Method lifecycle (backup, define, restore)
  # is entirely managed by the Marble class itself via the lazy method application
  # pattern.
  #
  # %a{rbs: class Context}
  class Context
    # : () -> Array[Marble]
    attr_reader :stack

    # Initialize a new context with empty stack
    #
    # : () -> void
    def initialize
      @stack = []
    end

    # Get or create thread-local context singleton
    #
    # : () -> Context
    def self.current
      Thread.current[:reality_marble_context] ||= new
    end

    # Reset context for cleanup (testing)
    #
    # : () -> nil
    def self.reset_current
      Thread.current[:reality_marble_context] = nil
    end

    # Check if stack is empty
    #
    # : () -> bool
    def empty?
      @stack.empty?
    end

    # Get current stack size
    #
    # : () -> Integer
    def size
      @stack.size
    end

    # Push marble onto the stack
    #
    # : (marble: Marble) -> Array[Marble]
    def push(marble)
      @stack.push(marble)
    end

    # Pop marble from the stack
    #
    # : () -> Marble | nil
    def pop
      @stack.pop
    end
  end
end
