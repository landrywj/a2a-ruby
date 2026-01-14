# frozen_string_literal: true

module A2a
  module Client
    # Base exception for A2A Client errors
    class Error < StandardError
    end

    # Client exception for HTTP errors received from the server
    class HTTPError < Error
      attr_reader :status_code, :message

      def initialize(status_code, message)
        @status_code = status_code
        @message = message
        super("HTTP Error #{status_code}: #{message}")
      end
    end

    # Client exception for JSON errors during response parsing or validation
    class JSONError < Error
      attr_reader :message

      def initialize(message)
        @message = message
        super("JSON Error: #{message}")
      end
    end

    # Client exception for timeout errors during a request
    class TimeoutError < Error
      attr_reader :message

      def initialize(message)
        @message = message
        super("Timeout Error: #{message}")
      end
    end

    # Client exception for invalid arguments passed to a method
    class InvalidArgsError < Error
      attr_reader :message

      def initialize(message)
        @message = message
        super("Invalid arguments error: #{message}")
      end
    end

    # Client exception for an invalid client state
    class InvalidStateError < Error
      attr_reader :message

      def initialize(message)
        @message = message
        super("Invalid state error: #{message}")
      end
    end

    # Client exception for JSON-RPC errors returned by the server
    class JSONRPCError < Error
      attr_reader :error

      def initialize(error)
        @error = error
        super("JSON-RPC Error #{error}")
      end
    end
  end
end
