# frozen_string_literal: true

require_relative "request_handler"
require_relative "../../server/errors"
require_relative "../../types"
require_relative "../../utils/task"

module A2a
  module Server
    module RequestHandlers
      # Default request handler for all incoming requests.
      #
      # This handler provides default implementations for all A2A JSON-RPC methods,
      # coordinating between the AgentExecutor, TaskStore, QueueManager,
      # and optional PushNotifier.
      #
      # Note: This is a basic implementation. Full implementation requires:
      # - AgentExecutor: Executes agent logic
      # - TaskStore: Manages task persistence
      # - QueueManager: Manages event queues
      # - PushNotificationConfigStore: Manages push notification configurations
      # - PushNotificationSender: Sends push notifications
      # - RequestContextBuilder: Builds request contexts
      class DefaultRequestHandler < RequestHandler
        TERMINAL_TASK_STATES = [
          Types::TaskState::COMPLETED,
          Types::TaskState::CANCELED,
          Types::TaskState::FAILED,
          Types::TaskState::REJECTED
        ].freeze

        attr_reader :agent_executor, :task_store, :queue_manager, :push_config_store, :push_sender, :request_context_builder

        def initialize(
          agent_executor:,
          task_store:,
          queue_manager: nil,
          push_config_store: nil,
          push_sender: nil,
          request_context_builder: nil
        )
          @agent_executor = agent_executor
          @task_store = task_store
          @queue_manager = queue_manager
          @push_config_store = push_config_store
          @push_sender = push_sender
          @request_context_builder = request_context_builder
          @running_agents = {}
          @running_agents_lock = Mutex.new
        end

        # Default handler for 'tasks/get'.
        #
        # @param params [Types::TaskQueryParams] Parameters specifying the task ID and optionally history length.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::Task, nil] The Task object if found, otherwise nil.
        def on_get_task(params, context = nil)
          task = @task_store.get(params.id, context)
          raise ServerError, Types::JSONRPCError.new(code: -32_001, message: "Task not found") unless task

          # Apply historyLength parameter if specified
          Utils::Task.apply_history_length(task, params.history_length)
        end

        # Default handler for 'tasks/cancel'.
        #
        # Attempts to cancel the task managed by the AgentExecutor.
        #
        # @param params [Types::TaskIdParams] Parameters specifying the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::Task, nil] The Task object with its status updated to canceled, or nil if the task was not found.
        def on_cancel_task(params, context = nil)
          task = @task_store.get(params.id, context)
          raise ServerError, Types::JSONRPCError.new(code: -32_001, message: "Task not found") unless task

          # Check if task is in a non-cancelable state
          if TERMINAL_TASK_STATES.include?(task.status.state)
            raise ServerError, Types::JSONRPCError.new(
              code: -32_002,
              message: "Task cannot be canceled - current state: #{task.status.state}"
            )
          end

          # Cancel the task
          # Note: Full implementation would use AgentExecutor.cancel and QueueManager
          # For now, we'll mark it as canceled directly
          task.status.state = Types::TaskState::CANCELED
          @task_store.save(task, context) if @task_store.respond_to?(:save)

          task
        end

        # Default handler for 'message/send' (non-streaming).
        #
        # @param params [Types::MessageSendParams] Parameters including the message and configuration.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::Task, Types::Message] The final Task object or a final Message object.
        def on_message_send(params, context = nil)
          raise NotImplementedError, "on_message_send requires AgentExecutor implementation"
        end

        # Default handler for 'message/stream' (streaming).
        #
        # @param params [Types::MessageSendParams] Parameters including the message and configuration.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @yield [Object] Event objects from the agent's execution
        # @return [Enumerator] An enumerator that yields Event objects
        def on_message_send_stream(params, context = nil)
          return enum_for(:on_message_send_stream, params, context) unless block_given?

          raise NotImplementedError, "on_message_send_stream requires AgentExecutor and QueueManager implementation"
        end

        # Default handler for 'tasks/pushNotificationConfig/set'.
        #
        # @param params [Types::TaskPushNotificationConfig] Parameters including the task ID and push notification configuration.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::TaskPushNotificationConfig] The provided TaskPushNotificationConfig upon success.
        def on_set_task_push_notification_config(params, context = nil)
          raise ServerError, Types::JSONRPCError.new(code: -32_601, message: "Push notifications are not supported") unless @push_config_store

          @push_config_store.save(params, context)
        end

        # Default handler for 'tasks/pushNotificationConfig/get'.
        #
        # @param params [Types::TaskIdParams, Types::GetTaskPushNotificationConfigParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::TaskPushNotificationConfig] The TaskPushNotificationConfig for the task.
        def on_get_task_push_notification_config(params, context = nil)
          raise ServerError, Types::JSONRPCError.new(code: -32_601, message: "Push notifications are not supported") unless @push_config_store

          config = @push_config_store.get(params.id, params.respond_to?(:push_notification_config_id) ? params.push_notification_config_id : nil,
                                          context)
          raise ServerError, Types::JSONRPCError.new(code: -32_001, message: "Push notification config not found") unless config

          config
        end

        # Default handler for 'tasks/resubscribe'.
        #
        # @param params [Types::TaskIdParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @yield [Object] Event objects from the agent's ongoing execution
        # @return [Enumerator] An enumerator that yields Event objects
        def on_resubscribe_to_task(params, context = nil)
          return enum_for(:on_resubscribe_to_task, params, context) unless block_given?

          raise NotImplementedError, "on_resubscribe_to_task requires QueueManager implementation"
        end

        # Default handler for 'tasks/pushNotificationConfig/list'.
        #
        # @param params [Types::ListTaskPushNotificationConfigParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Array<Types::TaskPushNotificationConfig>] The list of TaskPushNotificationConfig for the task.
        def on_list_task_push_notification_config(params, context = nil)
          raise ServerError, Types::JSONRPCError.new(code: -32_601, message: "Push notifications are not supported") unless @push_config_store

          @push_config_store.list(params.id, context) || []
        end

        # Default handler for 'tasks/pushNotificationConfig/delete'.
        #
        # @param params [Types::DeleteTaskPushNotificationConfigParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [nil]
        def on_delete_task_push_notification_config(params, context = nil)
          raise ServerError, Types::JSONRPCError.new(code: -32_601, message: "Push notifications are not supported") unless @push_config_store

          @push_config_store.delete(params.id, params.push_notification_config_id, context)
        end
      end
    end
  end
end
