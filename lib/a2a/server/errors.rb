# frozen_string_literal: true

module A2a
  module Server
    # Base exception for A2A Server errors
    class ServerError < StandardError
      attr_reader :error

      def initialize(error = nil)
        @error = error
        message = if error
                    error.respond_to?(:message) ? error.message : error.to_s
                  else
                    "Server error"
                  end
        super(message)
      end

      def to_s
        if @error
          @error.respond_to?(:message) ? @error.message : @error.to_s
        else
          super
        end
      end
    end
  end
end
