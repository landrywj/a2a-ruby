# frozen_string_literal: true

require_relative "params"

module A2a
  module Types
    # Represents a JSON-RPC 2.0 error object
    class JSONRPCError < BaseModel
      attr_accessor :code, :message, :data

      def initialize(attributes = {})
        super
        @code = attributes[:code] || attributes["code"]
        @message = attributes[:message] || attributes["message"]
        @data = attributes[:data] || attributes["data"]
      end
    end

    # Represents a JSON-RPC 2.0 error response
    class JSONRPCErrorResponse < BaseModel
      attr_accessor :id, :jsonrpc, :error

      def initialize(attributes = {})
        super
        @id = attributes[:id] || attributes["id"]
        @jsonrpc = attributes[:jsonrpc] || attributes["jsonrpc"] || "2.0"
        error_data = attributes[:error] || attributes["error"]
        @error = if error_data
                   error_data.is_a?(JSONRPCError) ? error_data : JSONRPCError.new(error_data)
                 end
      end
    end

    # Base class for JSON-RPC 2.0 requests
    class JSONRPCRequest < BaseModel
      attr_accessor :id, :jsonrpc, :method, :params

      def initialize(attributes = {})
        super
        @id = attributes[:id] || attributes["id"]
        @jsonrpc = attributes[:jsonrpc] || attributes["jsonrpc"] || "2.0"
        @method = attributes[:method] || attributes["method"]
        @params = attributes[:params] || attributes["params"]
      end
    end

    # Represents a JSON-RPC request for the `message/send` method
    class SendMessageRequest < JSONRPCRequest
      def initialize(attributes = {})
        super
        @method = "message/send"
        params_data = attributes[:params] || attributes["params"]
        @params = if params_data
                    params_data.is_a?(MessageSendParams) ? params_data : MessageSendParams.new(params_data)
                  end
      end
    end

    # Represents a JSON-RPC request for the `message/stream` method
    class SendStreamingMessageRequest < JSONRPCRequest
      def initialize(attributes = {})
        super
        @method = "message/stream"
        params_data = attributes[:params] || attributes["params"]
        @params = if params_data
                    params_data.is_a?(MessageSendParams) ? params_data : MessageSendParams.new(params_data)
                  end
      end
    end

    # Represents a JSON-RPC request for the `tasks/get` method
    class GetTaskRequest < JSONRPCRequest
      def initialize(attributes = {})
        super
        @method = "tasks/get"
        params_data = attributes[:params] || attributes["params"]
        @params = if params_data
                    params_data.is_a?(TaskQueryParams) ? params_data : TaskQueryParams.new(params_data)
                  end
      end
    end

    # Represents a JSON-RPC request for the `tasks/cancel` method
    class CancelTaskRequest < JSONRPCRequest
      def initialize(attributes = {})
        super
        @method = "tasks/cancel"
        params_data = attributes[:params] || attributes["params"]
        @params = if params_data
                    params_data.is_a?(TaskIdParams) ? params_data : TaskIdParams.new(params_data)
                  end
      end
    end

    # Represents a JSON-RPC request for the `tasks/pushNotificationConfig/set` method
    class SetTaskPushNotificationConfigRequest < JSONRPCRequest
      def initialize(attributes = {})
        super
        @method = "tasks/pushNotificationConfig/set"
        params_data = attributes[:params] || attributes["params"]
        @params = if params_data
                    params_data.is_a?(TaskPushNotificationConfig) ? params_data : TaskPushNotificationConfig.new(params_data)
                  end
      end
    end

    # Represents a JSON-RPC request for the `tasks/pushNotificationConfig/get` method
    class GetTaskPushNotificationConfigRequest < JSONRPCRequest
      def initialize(attributes = {})
        super
        @method = "tasks/pushNotificationConfig/get"
        params_data = attributes[:params] || attributes["params"]
        @params = if params_data
                    params_data.is_a?(GetTaskPushNotificationConfigParams) ? params_data : GetTaskPushNotificationConfigParams.new(params_data)
                  end
      end
    end

    # Represents a JSON-RPC request for the `tasks/resubscribe` method
    class TaskResubscriptionRequest < JSONRPCRequest
      def initialize(attributes = {})
        super
        @method = "tasks/resubscribe"
        params_data = attributes[:params] || attributes["params"]
        @params = if params_data
                    params_data.is_a?(TaskIdParams) ? params_data : TaskIdParams.new(params_data)
                  end
      end
    end

    # Represents a JSON-RPC request for the `agent/getAuthenticatedExtendedCard` method
    class GetAuthenticatedExtendedCardRequest < JSONRPCRequest
      def initialize(attributes = {})
        super
        @method = "agent/getAuthenticatedExtendedCard"
        @params = nil
      end
    end

    # Base class for JSON-RPC 2.0 success responses
    class JSONRPCSuccessResponse < BaseModel
      attr_accessor :id, :jsonrpc, :result

      def initialize(attributes = {})
        super
        @id = attributes[:id] || attributes["id"]
        @jsonrpc = attributes[:jsonrpc] || attributes["jsonrpc"] || "2.0"
        @result = attributes[:result] || attributes["result"]
      end
    end

    # Represents a successful JSON-RPC response for the `message/send` method
    class SendMessageSuccessResponse < JSONRPCSuccessResponse
    end

    # Represents a successful JSON-RPC response for the `message/stream` method
    class SendStreamingMessageSuccessResponse < JSONRPCSuccessResponse
    end

    # Represents a successful JSON-RPC response for the `tasks/get` method
    class GetTaskSuccessResponse < JSONRPCSuccessResponse
    end

    # Represents a successful JSON-RPC response for the `tasks/cancel` method
    class CancelTaskSuccessResponse < JSONRPCSuccessResponse
    end

    # Represents a successful JSON-RPC response for the `tasks/pushNotificationConfig/set` method
    class SetTaskPushNotificationConfigSuccessResponse < JSONRPCSuccessResponse
    end

    # Represents a successful JSON-RPC response for the `tasks/pushNotificationConfig/get` method
    class GetTaskPushNotificationConfigSuccessResponse < JSONRPCSuccessResponse
    end

    # Represents a successful JSON-RPC response for the `agent/getAuthenticatedExtendedCard` method
    class GetAuthenticatedExtendedCardSuccessResponse < JSONRPCSuccessResponse
    end
  end
end
