# frozen_string_literal: true

require_relative "base"
require_relative "task_manager"
require_relative "transports"
require_relative "../types"

module A2a
  module Client
    # Base implementation of the A2A client, containing transport-independent logic.
    class BaseClient < Base
      attr_reader :card, :config, :transport

      # Initializes the BaseClient.
      #
      # @param card [Types::AgentCard] The agent card
      # @param config [Config] The client configuration
      # @param transport [Transports::Base] The transport instance
      # @param consumers [Array] A list of consumers to process events
      # @param middleware [Array<CallInterceptor>] A list of interceptors
      def initialize(card:, config:, transport:, consumers: [], middleware: [])
        super(consumers: consumers, middleware: middleware)
        @card = card
        @config = config
        @transport = transport
      end

      # Sends a message to the agent.
      #
      # This method handles both streaming and non-streaming (polling) interactions
      # based on the client configuration and agent capabilities. It will yield
      # events as they are received from the agent.
      #
      # @param request [Types::Message] The message to send to the agent
      # @param configuration [Types::MessageSendConfiguration, nil] Optional per-call overrides for message sending behavior
      # @param context [CallContext, nil] The client call context
      # @param request_metadata [Hash, nil] Extensions Metadata attached to the request
      # @param extensions [Array<String>, nil] List of extensions to be activated
      # @return [Enumerator] An enumerator of ClientEvent or a final Message response
      def send_message(request:, configuration: nil, context: nil, request_metadata: nil, extensions: nil)
        base_config = Types::MessageSendConfiguration.new(
          accepted_output_modes: @config.accepted_output_modes || [],
          blocking: !@config.polling,
          push_notification_config: @config.push_notification_configs&.first
        )

        if configuration
          # Merge configuration overrides
          config_hash = base_config.to_h.merge(configuration.to_h.reject { |_k, v| v.nil? })
          final_config = Types::MessageSendConfiguration.new(config_hash)
        else
          final_config = base_config
        end

        params = Types::MessageSendParams.new(
          message: request,
          configuration: final_config,
          metadata: request_metadata
        )

        # Use non-streaming if client or server doesn't support streaming
        unless @config.streaming && @card.capabilities&.streaming
          response = @transport.send_message(
            request: params,
            context: context,
            extensions: extensions
          )
          result = response.is_a?(Types::Task) ? [response, nil] : response
          consume(result, @card)
          return Enumerator.new { |y| y << result }
        end

        # Use streaming
        tracker = TaskManager.new
        stream = @transport.send_message_streaming(
          request: params,
          context: context,
          extensions: extensions
        )

        Enumerator.new do |yielder|
          first_event = stream.next
          # The response from a server may be either exactly one Message or a
          # series of Task updates. Separate out the first message for special
          # case handling, which allows us to simplify further stream processing.
          if first_event.is_a?(Types::Message)
            consume(first_event, @card)
            yielder << first_event
            next
          end

          yielder << process_response(tracker, first_event)

          loop do
            event = stream.next
            yielder << process_response(tracker, event)
          end
        rescue StopIteration
          # Stream ended
        end
      end

      # Retrieves the current state and history of a specific task.
      #
      # @param request [Types::TaskQueryParams] The task query parameters
      # @param context [CallContext, nil] The client call context
      # @param extensions [Array<String>, nil] List of extensions to activate
      # @return [Types::Task] The task object
      def get_task(request:, context: nil, extensions: nil)
        @transport.get_task(
          request: request,
          context: context,
          extensions: extensions
        )
      end

      # Requests the agent to cancel a specific task.
      #
      # @param request [Types::TaskIdParams] The task ID parameters
      # @param context [CallContext, nil] The client call context
      # @param extensions [Array<String>, nil] List of extensions to activate
      # @return [Types::Task] The updated task object
      def cancel_task(request:, context: nil, extensions: nil)
        @transport.cancel_task(
          request: request,
          context: context,
          extensions: extensions
        )
      end

      # Sets or updates the push notification configuration for a specific task.
      #
      # @param request [Types::TaskPushNotificationConfig] The push notification config
      # @param context [CallContext, nil] The client call context
      # @param extensions [Array<String>, nil] List of extensions to activate
      # @return [Types::TaskPushNotificationConfig] The created or updated config
      def set_task_callback(request:, context: nil, extensions: nil)
        @transport.set_task_callback(
          request: request,
          context: context,
          extensions: extensions
        )
      end

      # Retrieves the push notification configuration for a specific task.
      #
      # @param request [Types::GetTaskPushNotificationConfigParams] The query parameters
      # @param context [CallContext, nil] The client call context
      # @param extensions [Array<String>, nil] List of extensions to activate
      # @return [Types::TaskPushNotificationConfig] The push notification config
      def get_task_callback(request:, context: nil, extensions: nil)
        @transport.get_task_callback(
          request: request,
          context: context,
          extensions: extensions
        )
      end

      # Resubscribes to a task's event stream.
      #
      # This is only available if both the client and server support streaming.
      #
      # @param request [Types::TaskIdParams] The task ID parameters
      # @param context [CallContext, nil] The client call context
      # @param extensions [Array<String>, nil] List of extensions to activate
      # @return [Enumerator] An enumerator of ClientEvent objects
      # @raise [NotImplementedError] If streaming is not supported by the client or server
      def resubscribe(request:, context: nil, extensions: nil)
        unless @config.streaming && @card.capabilities&.streaming
          raise NotImplementedError, "client and/or server do not support resubscription."
        end

        tracker = TaskManager.new
        stream = @transport.resubscribe(
          request: request,
          context: context,
          extensions: extensions
        )

        Enumerator.new do |yielder|
          loop do
            event = stream.next
            yielder << process_response(tracker, event)
          end
        rescue StopIteration
          # Stream ended
        end
      end

      # Retrieves the agent's card.
      #
      # This will fetch the authenticated card if necessary and update the
      # client's internal state with the new card.
      #
      # @param context [CallContext, nil] The client call context
      # @param extensions [Array<String>, nil] List of extensions to activate
      # @param signature_verifier [Proc, nil] A callable used to verify the agent card's signatures
      # @return [Types::AgentCard] The agent card
      def get_card(context: nil, extensions: nil, signature_verifier: nil)
        card = @transport.get_card(
          context: context,
          extensions: extensions,
          signature_verifier: signature_verifier
        )
        @card = card
        card
      end

      # Closes the underlying transport.
      def close
        @transport.close
      end

      private

      def process_response(tracker, event)
        if event.is_a?(Types::Message)
          raise InvalidStateError.new("received a streamed Message from server after first response; this is not supported")
        end

        tracker.process(event)
        task = tracker.get_task_or_raise
        update = event.is_a?(Types::Task) ? nil : event
        client_event = [task, update]
        consume(client_event, @card)
        client_event
      end
    end
  end
end
