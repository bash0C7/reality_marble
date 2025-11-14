module RealityMarble
  # Context: Thread-local management of active marbles with stack support
  #
  # Simplified context for the new native syntax API. The context now only
  # manages the stack of active marbles. Method lifecycle (backup, define, restore)
  # is entirely managed by the Marble class itself via the lazy method application
  # pattern.
  class Context
    attr_reader :stack

    def initialize
      @stack = []
    end

    # Get or create thread-local context singleton
    def self.current
      Thread.current[:reality_marble_context] ||= new
    end

    # Reset context for cleanup (testing)
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

    # Push marble onto the stack
    def push(marble)
      @stack.push(marble)
    end

    # Pop marble from the stack
    def pop
      @stack.pop
    end
  end
end
