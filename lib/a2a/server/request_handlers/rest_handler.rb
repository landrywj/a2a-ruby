# frozen_string_literal: true

require "json"
require_relative "request_handler"
require_relative "../../server/errors"
require_relative "../../types"

module A2a
  module Server
    module RequestHandlers
      # Maps incoming REST-like (JSON+HTTP) requests to the appropriate request handler method and formats responses.
      #
      # This handler maps REST API endpoints to the underlying RequestHandler methods.
      # It should be used if using gRPC with Envoy is not feasible for a given deployment solution.
      class RESTHandler
        attr_reader :agent_card, :request_handler

        def initialize(agent_card:, request_handler:)
          @agent_card = agent_card
          @request_handler = request_handler
        end

        # Handles the 'message/send' REST method.
        #
        # @param request_body [Hash, String] The request body (JSON parsed or raw)
        # @param context [ServerCallContext] Context provided by the server.
        # @return [Hash] A hash containing the result (Task or Message)
        def on_message_send(request_body, context)
          # Parse request body if it's a string
          body = request_body.is_a?(String) ? JSON.parse(request_body) : request_body

          # Convert to MessageSendParams
          params = Types::MessageSendParams.new(body)
          task_or_message = @request_handler.on_message_send(params, context)
          serialize_response(task_or_message)
        end

        # Handles the 'message/stream' REST method.
        #
        # Yields response objects as they are produced by the underlying handler's stream.
        #
        # @param request_body [Hash, String] The request body (JSON parsed or raw)
        # @param context [ServerCallContext] Context provided by the server.
        # @yield [String] JSON serialized objects containing streaming events
        # @return [Enumerator] An enumerator that yields JSON strings
        def on_message_send_stream(request_body, context)
          return enum_for(:on_message_send_stream, request_body, context) unless block_given?

          unless @agent_card.capabilities&.streaming
            raise ServerError, Types::JSONRPCError.new(code: -32_601, message: "Streaming is not supported by the agent")
          end

          # Parse request body if it's a string
          body = request_body.is_a?(String) ? JSON.parse(request_body) : request_body

          # Convert to MessageSendParams
          params = Types::MessageSendParams.new(body)
          @request_handler.on_message_send_stream(params, context) do |event|
            yield JSON.generate(serialize_response(event))
          end
        end

        # Handles the 'tasks/cancel' REST method.
        #
        # @param task_id [String] The task ID from the URL path
        # @param context [ServerCallContext] Context provided by the server.
        # @return [Hash] A hash containing the updated Task
        def on_cancel_task(task_id, context)
          params = Types::TaskIdParams.new(id: task_id)
          task = @request_handler.on_cancel_task(params, context)
          raise ServerError, Types::JSONRPCError.new(code: -32_001, message: "Task not found") unless task

          serialize_response(task)
        end

        # Handles the 'tasks/resubscribe' REST method.
        #
        # Yields response objects as they are produced by the underlying handler's stream.
        #
        # @param task_id [String] The task ID from the URL path
        # @param context [ServerCallContext] Context provided by the server.
        # @yield [String] JSON serialized objects containing streaming events
        # @return [Enumerator] An enumerator that yields JSON strings
        def on_resubscribe_to_task(task_id, context)
          return enum_for(:on_resubscribe_to_task, task_id, context) unless block_given?

          unless @agent_card.capabilities&.streaming
            raise ServerError, Types::JSONRPCError.new(code: -32_601, message: "Streaming is not supported by the agent")
          end

          params = Types::TaskIdParams.new(id: task_id)
          @request_handler.on_resubscribe_to_task(params, context) do |event|
            yield JSON.generate(serialize_response(event))
          end
        end

        # Handles the 'tasks/pushNotificationConfig/get' REST method.
        #
        # @param task_id [String] The task ID from the URL path
        # @param push_id [String] The push notification config ID from the URL path
        # @param context [ServerCallContext] Context provided by the server.
        # @return [Hash] A hash containing the config
        def get_push_notification(task_id, push_id, context)
          params = Types::GetTaskPushNotificationConfigParams.new(
            id: task_id,
            push_notification_config_id: push_id
          )
          config = @request_handler.on_get_task_push_notification_config(params, context)
          serialize_response(config)
        end

        # Handles the 'tasks/pushNotificationConfig/set' REST method.
        #
        # Requires the agent to support push notifications.
        #
        # @param task_id [String] The task ID from the URL path
        # @param request_body [Hash, String] The request body (JSON parsed or raw)
        # @param context [ServerCallContext] Context provided by the server.
        # @return [Hash] A hash containing the config object
        def set_push_notification(task_id, request_body, context)
          unless @agent_card.capabilities&.push_notifications
            raise ServerError, Types::JSONRPCError.new(code: -32_601, message: "Push notifications are not supported by the agent")
          end

          # Parse request body if it's a string
          body = request_body.is_a?(String) ? JSON.parse(request_body) : request_body

          # Convert to TaskPushNotificationConfig
          config_data = body.dup
          config_data["taskId"] ||= task_id
          params = Types::TaskPushNotificationConfig.new(config_data)
          config = @request_handler.on_set_task_push_notification_config(params, context)
          serialize_response(config)
        end

        # Handles the 'v1/tasks/{id}' REST method.
        #
        # @param task_id [String] The task ID from the URL path
        # @param history_length [Integer, nil] Optional history length from query params
        # @param context [ServerCallContext] Context provided by the server.
        # @return [Hash] A hash containing the Task
        def on_get_task(task_id, history_length = nil, context = nil)
          params = Types::TaskQueryParams.new(id: task_id, history_length: history_length)
          task = @request_handler.on_get_task(params, context)
          raise ServerError, Types::JSONRPCError.new(code: -32_001, message: "Task not found") unless task

          serialize_response(task)
        end

        # Handles the 'tasks/pushNotificationConfig/list' REST method.
        #
        # This method is currently not implemented.
        #
        # @param task_id [String] The task ID from the URL path
        # @param context [ServerCallContext] Context provided by the server.
        # @return [Array<Hash>] A list of hashes representing TaskPushNotificationConfig objects
        # @raise [NotImplementedError] This method is not yet implemented
        def list_push_notifications(task_id, context)
          raise NotImplementedError, "list notifications not implemented"
        end

        # Handles the 'tasks/list' REST method.
        #
        # This method is currently not implemented.
        #
        # @param context [ServerCallContext] Context provided by the server.
        # @return [Array<Hash>] A list of hashes representing Task objects
        # @raise [NotImplementedError] This method is not yet implemented
        def list_tasks(context)
          raise NotImplementedError, "list tasks not implemented"
        end

        private

        # Serializes a response object to a hash
        def serialize_response(obj)
          return nil if obj.nil?

          if obj.is_a?(Types::BaseModel)
            obj.to_h
          elsif obj.is_a?(Array)
            obj.map { |item| serialize_response(item) }
          else
            obj
          end
        end
      end
    end
  end
end
