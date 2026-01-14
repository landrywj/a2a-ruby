# frozen_string_literal: true

module A2a
  module Client
    module Transports
      # Abstract base class for a client transport.
      #
      # All transport implementations must implement the methods defined here.
      class Base
        # Sends a non-streaming message request to the agent.
        #
        # @param request [Types::MessageSendParams] The message send parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::Task, Types::Message] The response (Task or Message)
        def send_message(request:, context: nil, extensions: nil)
          raise NotImplementedError, "Subclasses must implement #send_message"
        end

        # Sends a streaming message request to the agent and yields responses as they arrive.
        #
        # @param request [Types::MessageSendParams] The message send parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Enumerator] An enumerator yielding Message, Task, TaskStatusUpdateEvent, or TaskArtifactUpdateEvent
        def send_message_streaming(request:, context: nil, extensions: nil)
          raise NotImplementedError, "Subclasses must implement #send_message_streaming"
        end

        # Retrieves the current state and history of a specific task.
        #
        # @param request [Types::TaskQueryParams] The task query parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::Task] The task object
        def get_task(request:, context: nil, extensions: nil)
          raise NotImplementedError, "Subclasses must implement #get_task"
        end

        # Requests the agent to cancel a specific task.
        #
        # @param request [Types::TaskIdParams] The task ID parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::Task] The updated task object
        def cancel_task(request:, context: nil, extensions: nil)
          raise NotImplementedError, "Subclasses must implement #cancel_task"
        end

        # Sets or updates the push notification configuration for a specific task.
        #
        # @param request [Types::TaskPushNotificationConfig] The push notification config
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::TaskPushNotificationConfig] The created or updated config
        def set_task_callback(request:, context: nil, extensions: nil)
          raise NotImplementedError, "Subclasses must implement #set_task_callback"
        end

        # Retrieves the push notification configuration for a specific task.
        #
        # @param request [Types::GetTaskPushNotificationConfigParams] The query parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::TaskPushNotificationConfig] The push notification config
        def get_task_callback(request:, context: nil, extensions: nil)
          raise NotImplementedError, "Subclasses must implement #get_task_callback"
        end

        # Reconnects to get task updates.
        #
        # @param request [Types::TaskIdParams] The task ID parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Enumerator] An enumerator yielding Task, Message, TaskStatusUpdateEvent, or TaskArtifactUpdateEvent
        def resubscribe(request:, context: nil, extensions: nil)
          raise NotImplementedError, "Subclasses must implement #resubscribe"
        end

        # Retrieves the AgentCard.
        #
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @param signature_verifier [Proc, nil] A callable used to verify the agent card's signatures
        # @return [Types::AgentCard] The agent card
        def get_card(context: nil, extensions: nil, signature_verifier: nil)
          raise NotImplementedError, "Subclasses must implement #get_card"
        end

        # Closes the transport.
        def close
          raise NotImplementedError, "Subclasses must implement #close"
        end
      end
    end
  end
end
