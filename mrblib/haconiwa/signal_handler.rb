module Haconiwa
  class SignalHandler
    def initialize
      @handlers = {}
    end
    attr_reader :handlers

    def registered_signals
      @handlers.keys
    end

    def each(&b)
      @handlers.each(&b)
    end

    def add_handler(sig, &b)
      if [:USR1, :USR2, :TTIN, :TTOU].include? sig.to_sym
        @handlers["SIG#{sig}".to_sym] = b
      else
        raise TypeError, "Unsupported signal: #{sig.inspect}"
      end
    end
  end
end
