# frozen_string_literal: true

# gRPC transport for the A2A client.
#
# Note: This transport requires:
# 1. The grpc gem to be installed: gem install grpc
# 2. The A2A protobuf files to be generated from the A2A protocol specification
#
# See README for instructions on generating proto files.

begin
  require "grpc"
rescue LoadError => e
  raise LoadError, "A2AGrpcTransport requires grpc gem to be installed. Install with: gem install grpc"
end

require_relative "base"
require_relative "../../types"
require_relative "../../utils/proto_utils"
require_relative "../card_resolver"
require_relative "../errors"

module A2a
  module Client
    module Transports
      # A gRPC transport for the A2A client.
      class Grpc < Base
        attr_reader :channel, :agent_card, :interceptors, :extensions, :stub

        # Initializes the Grpc transport.
        #
        # @param channel [GRPC::ClientStub] A gRPC channel instance
        # @param agent_card [Types::AgentCard, nil] The agent card
        # @param interceptors [Array<CallInterceptor>] A list of interceptors
        # @param extensions [Array<String>, nil] List of extensions to activate
        def initialize(channel:, agent_card: nil, interceptors: [], extensions: nil)
          @channel = channel
          @agent_card = agent_card
          @interceptors = interceptors || []
          @extensions = extensions
          @needs_extended_card = if agent_card
                                  agent_card.supports_authenticated_extended_card == true
                                else
                                  true
                                end

          # Get the gRPC service stub
          # Note: The actual stub class name depends on how proto files are generated
          # This assumes the generated files follow the pattern: A2a::Grpc::A2aServicesPb::A2AService::Stub
          begin
            # Try to load the service stub
            # The exact module path will depend on proto file generation
            # First try the expected path
            stub_class = begin
              A2a::Grpc::A2aServicesPb::A2AService::Stub
            rescue NameError
              # Try loading the file explicitly
              require_relative "../../grpc/a2a_services_pb"
              A2a::Grpc::A2aServicesPb::A2AService::Stub
            end
            @stub = stub_class.new(nil, channel: @channel)
          rescue NameError, LoadError => e
            raise LoadError, "A2A gRPC service stubs not found. Please generate proto files from the A2A protocol specification. Error: #{e.message}"
          end
        end

        # Creates a gRPC transport for the A2A client.
        #
        # @param card [Types::AgentCard] The agent card
        # @param url [String] The URL to connect to
        # @param config [Config] The client configuration
        # @param interceptors [Array<CallInterceptor>] A list of interceptors
        # @return [Grpc] A Grpc transport instance
        def self.create(card:, url:, config:, interceptors:)
          if config.grpc_channel_factory.nil?
            raise ArgumentError, "grpc_channel_factory is required when using gRPC"
          end

          channel = config.grpc_channel_factory.call(url)
          new(
            channel: channel,
            agent_card: card,
            interceptors: interceptors || [],
            extensions: config.extensions
          )
        end

        # Sends a non-streaming message request to the agent.
        #
        # @param request [Types::MessageSendParams] The message send parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::Task, Types::Message] The response (Task or Message)
        def send_message(request:, context: nil, extensions: nil)
          proto_request = Utils::ToProto.message_send_request(request)
          metadata = get_grpc_metadata(extensions || @extensions)

          # Apply interceptors if needed
          # Note: gRPC interceptors work differently than HTTP interceptors
          # For now, we'll pass metadata through interceptors
          final_metadata = apply_interceptors("message/send", proto_request, metadata, context)

          response = @stub.send_message(proto_request, metadata: final_metadata)

          # Check which field is set in the response
          # Ruby protobuf uses different field presence checking
          if response.respond_to?(:task) && response.task && !response.task.to_s.empty?
            Utils::FromProto.task(response.task)
          elsif response.respond_to?(:msg) && response.msg && !response.msg.to_s.empty?
            Utils::FromProto.message(response.msg)
          else
            raise GrpcError.new(GRPC::Core::StatusCodes::INTERNAL, "Invalid response from server")
          end
        end

        # Sends a streaming message request to the agent and yields responses as they arrive.
        #
        # @param request [Types::MessageSendParams] The message send parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Enumerator] An enumerator yielding Message, Task, TaskStatusUpdateEvent, or TaskArtifactUpdateEvent
        def send_message_streaming(request:, context: nil, extensions: nil)
          proto_request = Utils::ToProto.message_send_request(request)
          metadata = get_grpc_metadata(extensions || @extensions)
          final_metadata = apply_interceptors("message/stream", proto_request, metadata, context)

          Enumerator.new do |yielder|
            call = @stub.send_streaming_message(proto_request, metadata: final_metadata)
            loop do
              begin
                response = call.read
                result = Utils::FromProto.stream_response(response)
                yielder << result
              rescue GRPC::BadStatus => e
                raise GrpcError.new(e.code, e.details || e.message)
              end
            end
          rescue StopIteration
            # Stream ended normally
          ensure
            call&.close
          end
        end

        # Retrieves the current state and history of a specific task.
        #
        # @param request [Types::TaskQueryParams] The task query parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::Task] The task object
        def get_task(request:, context: nil, extensions: nil)
          proto_class = get_proto_class("GetTaskRequest")
          proto_request = proto_class.new(
            name: "tasks/#{request.id}",
            history_length: request.history_length || 0
          )
          metadata = get_grpc_metadata(extensions || @extensions)
          final_metadata = apply_interceptors("tasks/get", proto_request, metadata, context)

          task_pb = @stub.get_task(proto_request, metadata: final_metadata)
          Utils::FromProto.task(task_pb)
        end

        # Requests the agent to cancel a specific task.
        #
        # @param request [Types::TaskIdParams] The task ID parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::Task] The updated task object
        def cancel_task(request:, context: nil, extensions: nil)
          proto_class = get_proto_class("CancelTaskRequest")
          proto_request = proto_class.new(name: "tasks/#{request.id}")
          metadata = get_grpc_metadata(extensions || @extensions)
          final_metadata = apply_interceptors("tasks/cancel", proto_request, metadata, context)

          task_pb = @stub.cancel_task(proto_request, metadata: final_metadata)
          Utils::FromProto.task(task_pb)
        end

        # Sets or updates the push notification configuration for a specific task.
        #
        # @param request [Types::TaskPushNotificationConfig] The push notification config
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::TaskPushNotificationConfig] The created or updated config
        def set_task_callback(request:, context: nil, extensions: nil)
          proto_class = get_proto_class("CreateTaskPushNotificationConfigRequest")
          proto_request = proto_class.new(
            parent: "tasks/#{request.task_id}",
            config_id: request.push_notification_config.id,
            config: Utils::ToProto.task_push_notification_config(request)
          )
          metadata = get_grpc_metadata(extensions || @extensions)
          final_metadata = apply_interceptors("tasks/pushNotificationConfig/set", proto_request, metadata, context)

          config_pb = @stub.create_task_push_notification_config(proto_request, metadata: final_metadata)
          Utils::FromProto.task_push_notification_config(config_pb)
        end

        # Retrieves the push notification configuration for a specific task.
        #
        # @param request [Types::GetTaskPushNotificationConfigParams] The query parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::TaskPushNotificationConfig] The push notification config
        def get_task_callback(request:, context: nil, extensions: nil)
          proto_class = get_proto_class("GetTaskPushNotificationConfigRequest")
          proto_request = proto_class.new(
            name: "tasks/#{request.id}/pushNotificationConfigs/#{request.push_notification_config_id}"
          )
          metadata = get_grpc_metadata(extensions || @extensions)
          final_metadata = apply_interceptors("tasks/pushNotificationConfig/get", proto_request, metadata, context)

          config_pb = @stub.get_task_push_notification_config(proto_request, metadata: final_metadata)
          Utils::FromProto.task_push_notification_config(config_pb)
        end

        # Reconnects to get task updates.
        #
        # @param request [Types::TaskIdParams] The task ID parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Enumerator] An enumerator yielding Task, Message, TaskStatusUpdateEvent, or TaskArtifactUpdateEvent
        def resubscribe(request:, context: nil, extensions: nil)
          proto_class = get_proto_class("TaskSubscriptionRequest")
          proto_request = proto_class.new(name: "tasks/#{request.id}")
          metadata = get_grpc_metadata(extensions || @extensions)
          final_metadata = apply_interceptors("tasks/resubscribe", proto_request, metadata, context)

          Enumerator.new do |yielder|
            call = @stub.task_subscription(proto_request, metadata: final_metadata)
            loop do
              begin
                response = call.read
                result = Utils::FromProto.stream_response(response)
                yielder << result
              rescue GRPC::BadStatus => e
                raise GrpcError.new(e.code, e.details || e.message)
              end
            end
          rescue StopIteration
            # Stream ended normally
          ensure
            call&.close
          end
        end

        # Retrieves the AgentCard.
        #
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @param signature_verifier [Proc, nil] A callable used to verify the agent card's signatures
        # @return [Types::AgentCard] The agent card
        def get_card(context: nil, extensions: nil, signature_verifier: nil)
          card = @agent_card
          return card if card && !@needs_extended_card

          if card.nil? && !@needs_extended_card
            raise ArgumentError, "Agent card is not available."
          end

          proto_class = get_proto_class("GetAgentCardRequest")
          proto_request = proto_class.new
          metadata = get_grpc_metadata(extensions || @extensions)
          final_metadata = apply_interceptors("card/get", proto_request, metadata, context)

          card_pb = @stub.get_agent_card(proto_request, metadata: final_metadata)
          card = Utils::FromProto.agent_card(card_pb)
          signature_verifier&.call(card)

          @agent_card = card
          @needs_extended_card = false
          card
        end

        # Closes the gRPC channel.
        def close
          @channel&.close
        end

        private

        # Creates gRPC metadata for extensions.
        def get_grpc_metadata(extensions)
          return {} if extensions.nil? || extensions.empty?

          { "x-a2a-extensions" => extensions.join(",") }
        end

        # Applies interceptors to modify request and metadata.
        def apply_interceptors(method_name, proto_request, metadata, context)
          final_metadata = metadata || {}

          @interceptors.each do |interceptor|
            # Convert proto request to hash for interceptor
            request_hash = proto_to_hash(proto_request)
            final_request_hash, final_metadata = interceptor.intercept(
              method_name,
              request_hash,
              { headers: final_metadata },
              @agent_card,
              context
            )
            # Note: We can't easily convert back from hash to proto, so we'll just use the metadata
            final_metadata = final_metadata[:headers] || final_metadata
          end

          final_metadata
        end

        # Helper to convert proto message to hash (simplified)
        def proto_to_hash(proto_msg)
          # This is a simplified conversion - in practice, you might want to use
          # the proto's to_h method if available, or JSON serialization
          JSON.parse(proto_msg.to_json)
        rescue StandardError
          {}
        end

        # Helper to get proto class by name
        def get_proto_class(class_name)
          begin
            A2a::Grpc::A2aPb2.const_get(class_name)
          rescue NameError
            raise LoadError, "A2A protobuf files not found. Please generate proto files from the A2A protocol specification."
          end
        end
      end

      # Custom error class for gRPC errors
      class GrpcError < StandardError
        attr_reader :code, :details

        def initialize(code, details = nil)
          @code = code
          @details = details
          super("gRPC error (#{code}): #{details || 'Unknown error'}")
        end
      end
    end
  end
end
