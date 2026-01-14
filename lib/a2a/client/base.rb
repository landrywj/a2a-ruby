# frozen_string_literal: true

module A2a
  module Client
    # Abstract base class defining the interface for an A2A client.
    #
    # This class provides a standard set of methods for interacting with an A2A
    # agent, regardless of the underlying transport protocol (e.g., gRPC, JSON-RPC).
    # It supports sending messages, managing tasks, and handling event streams.
    class Base
      attr_reader :consumers, :middleware

      # Initializes the client with consumers and middleware.
      #
      # @param consumers [Array] A list of callables to process events from the agent
      # @param middleware [Array<CallInterceptor>] A list of interceptors to process requests and responses
      def initialize(consumers: [], middleware: [])
        @consumers = consumers || []
        @middleware = middleware || []
      end

      # Sends a message to the server.
      #
      # This will automatically use the streaming or non-streaming approach
      # as supported by the server and the client config. Client will
      # aggregate update events and return an iterator of (Task, Update)
      # pairs, or a Message. Client will also send these values to any
      # configured consumers in the client.
      #
      # @param request [Types::Message] The message to send
      # @param context [CallContext, nil] The client call context
      # @param request_metadata [Hash, nil] Request metadata
      # @param extensions [Array<String>, nil] List of extensions to activate
      # @return [Enumerator] An enumerator of ClientEvent or Message
      def send_message(request:, context: nil, request_metadata: nil, extensions: nil)
        raise NotImplementedError, "Subclasses must implement #send_message"
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

      # Resubscribes to a task's event stream.
      #
      # @param request [Types::TaskIdParams] The task ID parameters
      # @param context [CallContext, nil] The client call context
      # @param extensions [Array<String>, nil] List of extensions to activate
      # @return [Enumerator] An enumerator of ClientEvent objects
      def resubscribe(request:, context: nil, extensions: nil)
        raise NotImplementedError, "Subclasses must implement #resubscribe"
      end

      # Retrieves the agent's card.
      #
      # @param context [CallContext, nil] The client call context
      # @param extensions [Array<String>, nil] List of extensions to activate
      # @param signature_verifier [Proc, nil] A callable used to verify the agent card's signatures
      # @return [Types::AgentCard] The agent card
      def get_card(context: nil, extensions: nil, signature_verifier: nil)
        raise NotImplementedError, "Subclasses must implement #get_card"
      end

      # Attaches additional consumers to the Client.
      #
      # @param consumer [Proc] A consumer to add
      def add_event_consumer(consumer)
        @consumers << consumer
      end

      # Attaches additional middleware to the Client.
      #
      # @param middleware [CallInterceptor] A middleware interceptor to add
      def add_request_middleware(middleware)
        @middleware << middleware
      end

      # Processes the event via all the registered consumers.
      #
      # @param event [Array, Types::Message, nil] The event to consume
      # @param card [Types::AgentCard] The agent card
      def consume(event, card)
        return unless event

        @consumers.each do |consumer|
          consumer.call(event, card)
        end
      end
    end
  end
end
