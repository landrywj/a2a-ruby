# frozen_string_literal: true

module A2a
  module Server
    module RequestHandlers
      # A2A request handler interface.
      # This interface defines the methods that an A2A server implementation must
      # provide to handle incoming JSON-RPC requests.
      class RequestHandler
        # Handles the 'tasks/get' method.
        # Retrieves the state and history of a specific task.
        #
        # @param params [Types::TaskQueryParams] Parameters specifying the task ID and optionally history length.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::Task, nil] The Task object if found, otherwise nil.
        def on_get_task(params, context = nil)
          raise NotImplementedError, "on_get_task must be implemented"
        end

        # Handles the 'tasks/cancel' method.
        # Requests the agent to cancel an ongoing task.
        #
        # @param params [Types::TaskIdParams] Parameters specifying the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::Task, nil] The Task object with its status updated to canceled, or nil if the task was not found.
        def on_cancel_task(params, context = nil)
          raise NotImplementedError, "on_cancel_task must be implemented"
        end

        # Handles the 'message/send' method (non-streaming).
        # Sends a message to the agent to create, continue, or restart a task,
        # and waits for the final result (Task or Message).
        #
        # @param params [Types::MessageSendParams] Parameters including the message and configuration.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::Task, Types::Message] The final Task object or a final Message object.
        def on_message_send(params, context = nil)
          raise NotImplementedError, "on_message_send must be implemented"
        end

        # Handles the 'message/stream' method (streaming).
        # Sends a message to the agent and yields stream events as they are
        # produced (Task updates, Message chunks, Artifact updates).
        #
        # @param params [Types::MessageSendParams] Parameters including the message and configuration.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @yield [Object] Event objects from the agent's execution.
        # @return [Enumerator] An enumerator that yields Event objects
        def on_message_send_stream(params, context = nil)
          raise NotImplementedError, "on_message_send_stream must be implemented"
        end

        # Handles the 'tasks/pushNotificationConfig/set' method.
        # Sets or updates the push notification configuration for a task.
        #
        # @param params [Types::TaskPushNotificationConfig] Parameters including the task ID and push notification configuration.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::TaskPushNotificationConfig] The provided TaskPushNotificationConfig upon success.
        def on_set_task_push_notification_config(params, context = nil)
          raise NotImplementedError, "on_set_task_push_notification_config must be implemented"
        end

        # Handles the 'tasks/pushNotificationConfig/get' method.
        # Retrieves the current push notification configuration for a task.
        #
        # @param params [Types::TaskIdParams, Types::GetTaskPushNotificationConfigParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::TaskPushNotificationConfig] The TaskPushNotificationConfig for the task.
        def on_get_task_push_notification_config(params, context = nil)
          raise NotImplementedError, "on_get_task_push_notification_config must be implemented"
        end

        # Handles the 'tasks/resubscribe' method.
        # Allows a client to re-subscribe to a running streaming task's event stream.
        #
        # @param params [Types::TaskIdParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @yield [Object] Event objects from the agent's ongoing execution for the specified task.
        # @return [Enumerator] An enumerator that yields Event objects
        def on_resubscribe_to_task(params, context = nil)
          raise NotImplementedError, "on_resubscribe_to_task must be implemented"
        end

        # Handles the 'tasks/pushNotificationConfig/list' method.
        # Retrieves the current push notification configurations for a task.
        #
        # @param params [Types::ListTaskPushNotificationConfigParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Array<Types::TaskPushNotificationConfig>] The list of TaskPushNotificationConfig for the task.
        def on_list_task_push_notification_config(params, context = nil)
          raise NotImplementedError, "on_list_task_push_notification_config must be implemented"
        end

        # Handles the 'tasks/pushNotificationConfig/delete' method.
        # Deletes a push notification configuration associated with a task.
        #
        # @param params [Types::DeleteTaskPushNotificationConfigParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [nil]
        def on_delete_task_push_notification_config(params, context = nil)
          raise NotImplementedError, "on_delete_task_push_notification_config must be implemented"
        end
      end
    end
  end
end
