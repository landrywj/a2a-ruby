# frozen_string_literal: true

require_relative "request_handler"
require_relative "response_helpers"
require_relative "../../server/errors"
require_relative "../../types"

module A2a
  module Server
    module RequestHandlers
      # Maps incoming JSON-RPC requests to the appropriate request handler method and formats responses.
      class JSONRPCHandler
        attr_reader :agent_card, :request_handler, :extended_agent_card, :extended_card_modifier, :card_modifier

        def initialize(
          agent_card:,
          request_handler:,
          extended_agent_card: nil,
          extended_card_modifier: nil,
          card_modifier: nil
        )
          @agent_card = agent_card
          @request_handler = request_handler
          @extended_agent_card = extended_agent_card
          @extended_card_modifier = extended_card_modifier
          @card_modifier = card_modifier
        end

        # Handles the 'message/send' JSON-RPC method.
        #
        # @param request [Types::SendMessageRequest] The incoming SendMessageRequest object.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::JSONRPCSuccessResponse, Types::JSONRPCErrorResponse] A JSON-RPC response
        def on_message_send(request, context = nil)
          task_or_message = @request_handler.on_message_send(request.params, context)
          ResponseHelpers.prepare_response_object(
            request.id,
            task_or_message,
            [Types::Task, Types::Message],
            Types::SendMessageSuccessResponse
          )
        rescue ServerError => e
          error = e.error || Types::JSONRPCError.new(code: -32_603, message: "Internal error")
          ResponseHelpers.build_error_response(request.id, error)
        end

        # Handles the 'message/stream' JSON-RPC method.
        #
        # Yields response objects as they are produced by the underlying handler's stream.
        #
        # @param request [Types::SendStreamingMessageRequest] The incoming SendStreamingMessageRequest object.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @yield [Types::SendStreamingMessageSuccessResponse, Types::JSONRPCErrorResponse] Response objects
        # @return [Enumerator] An enumerator that yields response objects
        def on_message_send_stream(request, context = nil)
          return enum_for(:on_message_send_stream, request, context) unless block_given?

          unless @agent_card.capabilities&.streaming
            error = Types::JSONRPCError.new(
              code: -32_601,
              message: "Streaming is not supported by the agent"
            )
            yield ResponseHelpers.build_error_response(request.id, error)
            return
          end

          @request_handler.on_message_send_stream(request.params, context) do |event|
            yield ResponseHelpers.prepare_response_object(
              request.id,
              event,
              [Types::Task, Types::Message, Types::TaskArtifactUpdateEvent, Types::TaskStatusUpdateEvent],
              Types::SendStreamingMessageSuccessResponse
            )
          end
        rescue ServerError => e
          error = e.error || Types::JSONRPCError.new(code: -32_603, message: "Internal error")
          yield ResponseHelpers.build_error_response(request.id, error)
        end

        # Handles the 'tasks/cancel' JSON-RPC method.
        #
        # @param request [Types::CancelTaskRequest] The incoming CancelTaskRequest object.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::JSONRPCSuccessResponse, Types::JSONRPCErrorResponse] A JSON-RPC response
        def on_cancel_task(request, context = nil)
          task = @request_handler.on_cancel_task(request.params, context)
          if task
            ResponseHelpers.prepare_response_object(
              request.id,
              task,
              [Types::Task],
              Types::CancelTaskSuccessResponse
            )
          else
            error = Types::JSONRPCError.new(code: -32_001, message: "Task not found")
            ResponseHelpers.build_error_response(request.id, error)
          end
        rescue ServerError => e
          error = e.error || Types::JSONRPCError.new(code: -32_603, message: "Internal error")
          ResponseHelpers.build_error_response(request.id, error)
        end

        # Handles the 'tasks/resubscribe' JSON-RPC method.
        #
        # Yields response objects as they are produced by the underlying handler's stream.
        #
        # @param request [Types::TaskResubscriptionRequest] The incoming TaskResubscriptionRequest object.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @yield [Types::SendStreamingMessageSuccessResponse, Types::JSONRPCErrorResponse] Response objects
        # @return [Enumerator] An enumerator that yields response objects
        def on_resubscribe_to_task(request, context = nil)
          return enum_for(:on_resubscribe_to_task, request, context) unless block_given?

          @request_handler.on_resubscribe_to_task(request.params, context) do |event|
            yield ResponseHelpers.prepare_response_object(
              request.id,
              event,
              [Types::Task, Types::Message, Types::TaskArtifactUpdateEvent, Types::TaskStatusUpdateEvent],
              Types::SendStreamingMessageSuccessResponse
            )
          end
        rescue ServerError => e
          error = e.error || Types::JSONRPCError.new(code: -32_603, message: "Internal error")
          yield ResponseHelpers.build_error_response(request.id, error)
        end

        # Handles the 'tasks/pushNotificationConfig/get' JSON-RPC method.
        #
        # @param request [Types::GetTaskPushNotificationConfigRequest] The incoming request object.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::JSONRPCSuccessResponse, Types::JSONRPCErrorResponse] A JSON-RPC response
        def get_push_notification_config(request, context = nil)
          config = @request_handler.on_get_task_push_notification_config(request.params, context)
          ResponseHelpers.prepare_response_object(
            request.id,
            config,
            [Types::TaskPushNotificationConfig],
            Types::GetTaskPushNotificationConfigSuccessResponse
          )
        rescue ServerError => e
          error = e.error || Types::JSONRPCError.new(code: -32_603, message: "Internal error")
          ResponseHelpers.build_error_response(request.id, error)
        end

        # Handles the 'tasks/pushNotificationConfig/set' JSON-RPC method.
        #
        # Requires the agent to support push notifications.
        #
        # @param request [Types::SetTaskPushNotificationConfigRequest] The incoming request object.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::JSONRPCSuccessResponse, Types::JSONRPCErrorResponse] A JSON-RPC response
        def set_push_notification_config(request, context = nil)
          unless @agent_card.capabilities&.push_notifications
            error = Types::JSONRPCError.new(
              code: -32_601,
              message: "Push notifications are not supported by the agent"
            )
            return ResponseHelpers.build_error_response(request.id, error)
          end

          config = @request_handler.on_set_task_push_notification_config(request.params, context)
          ResponseHelpers.prepare_response_object(
            request.id,
            config,
            [Types::TaskPushNotificationConfig],
            Types::SetTaskPushNotificationConfigSuccessResponse
          )
        rescue ServerError => e
          error = e.error || Types::JSONRPCError.new(code: -32_603, message: "Internal error")
          ResponseHelpers.build_error_response(request.id, error)
        end

        # Handles the 'tasks/get' JSON-RPC method.
        #
        # @param request [Types::GetTaskRequest] The incoming GetTaskRequest object.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::JSONRPCSuccessResponse, Types::JSONRPCErrorResponse] A JSON-RPC response
        def on_get_task(request, context = nil)
          task = @request_handler.on_get_task(request.params, context)
          if task
            ResponseHelpers.prepare_response_object(
              request.id,
              task,
              [Types::Task],
              Types::GetTaskSuccessResponse
            )
          else
            error = Types::JSONRPCError.new(code: -32_001, message: "Task not found")
            ResponseHelpers.build_error_response(request.id, error)
          end
        rescue ServerError => e
          error = e.error || Types::JSONRPCError.new(code: -32_603, message: "Internal error")
          ResponseHelpers.build_error_response(request.id, error)
        end

        # Handles the 'tasks/pushNotificationConfig/list' JSON-RPC method.
        #
        # @param request [Types::ListTaskPushNotificationConfigRequest] The incoming request object.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::JSONRPCSuccessResponse, Types::JSONRPCErrorResponse] A JSON-RPC response
        def list_push_notification_config(request, context = nil)
          configs = @request_handler.on_list_task_push_notification_config(request.params, context)
          ResponseHelpers.prepare_response_object(
            request.id,
            configs,
            [Array],
            Types::ListTaskPushNotificationConfigSuccessResponse
          )
        rescue ServerError => e
          error = e.error || Types::JSONRPCError.new(code: -32_603, message: "Internal error")
          ResponseHelpers.build_error_response(request.id, error)
        end

        # Handles the 'tasks/pushNotificationConfig/delete' JSON-RPC method.
        #
        # @param request [Types::DeleteTaskPushNotificationConfigRequest] The incoming request object.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::JSONRPCSuccessResponse, Types::JSONRPCErrorResponse] A JSON-RPC response
        def delete_push_notification_config(request, context = nil)
          @request_handler.on_delete_task_push_notification_config(request.params, context)
          Types::DeleteTaskPushNotificationConfigSuccessResponse.new(id: request.id, result: nil)
        rescue ServerError => e
          error = e.error || Types::JSONRPCError.new(code: -32_603, message: "Internal error")
          ResponseHelpers.build_error_response(request.id, error)
        end

        # Handles the 'agent/getAuthenticatedExtendedCard' JSON-RPC method.
        #
        # @param request [Types::GetAuthenticatedExtendedCardRequest] The incoming request object.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::JSONRPCSuccessResponse, Types::JSONRPCErrorResponse] A JSON-RPC response
        def get_authenticated_extended_card(request, context = nil)
          unless @agent_card.supports_authenticated_extended_card
            error = Types::JSONRPCError.new(
              code: -32_007,
              message: "Authenticated Extended Card is not configured"
            )
            return ResponseHelpers.build_error_response(request.id, error)
          end

          base_card = @extended_agent_card || @agent_card
          card_to_serve = base_card

          if @extended_card_modifier && context
            card_to_serve = @extended_card_modifier.call(base_card, context)
          elsif @card_modifier
            card_to_serve = @card_modifier.call(base_card)
          end

          Types::GetAuthenticatedExtendedCardSuccessResponse.new(
            id: request.id,
            result: card_to_serve
          )
        rescue ServerError => e
          error = e.error || Types::JSONRPCError.new(code: -32_603, message: "Internal error")
          ResponseHelpers.build_error_response(request.id, error)
        end
      end
    end
  end
end
