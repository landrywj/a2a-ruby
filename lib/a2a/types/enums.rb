# frozen_string_literal: true

module A2a
  module Types
    # The location of the API key
    module In
      COOKIE = "cookie"
      HEADER = "header"
      QUERY = "query"
    end

    # Identifies the sender of the message
    module Role
      AGENT = "agent"
      USER = "user"
    end

    # Defines the lifecycle states of a Task
    module TaskState
      SUBMITTED = "submitted"
      WORKING = "working"
      INPUT_REQUIRED = "input-required"
      COMPLETED = "completed"
      CANCELED = "canceled"
      FAILED = "failed"
      REJECTED = "rejected"
      AUTH_REQUIRED = "auth-required"
      UNKNOWN = "unknown"
    end

    # Supported A2A transport protocols
    module TransportProtocol
      JSONRPC = "JSONRPC"
      GRPC = "GRPC"
      HTTP_JSON = "HTTP+JSON"
    end
  end
end
