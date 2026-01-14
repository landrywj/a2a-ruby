# frozen_string_literal: true

require "faraday"
require "json"
require "securerandom"
require_relative "base"
require_relative "../../types"
require_relative "../card_resolver"
require_relative "../errors"

module A2a
  module Client
    module Transports
      # A JSON-RPC transport for the A2A client.
      class JSONRPC < Base
        attr_reader :url, :agent_card, :interceptors, :extensions, :http_client

        # Initializes the JSONRPC transport.
        #
        # @param http_client [Faraday::Connection] An HTTP client instance
        # @param agent_card [Types::AgentCard, nil] The agent card
        # @param url [String, nil] The URL to connect to
        # @param interceptors [Array<CallInterceptor>] A list of interceptors
        # @param extensions [Array<String>, nil] List of extensions to activate
        def initialize(http_client:, agent_card: nil, url: nil, interceptors: [], extensions: nil)
          @url = url || (agent_card&.url)
          raise ArgumentError, "Must provide either agent_card or url" unless @url

          @http_client = http_client
          @agent_card = agent_card
          @interceptors = interceptors || []
          @extensions = extensions
          @needs_extended_card = if agent_card
                                   agent_card.supports_authenticated_extended_card == true
                                 else
                                   true
                                 end
        end

        # Sends a non-streaming message request to the agent.
        #
        # @param request [Types::MessageSendParams] The message send parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::Task, Types::Message] The response (Task or Message)
        def send_message(request:, context: nil, extensions: nil)
          rpc_request = Types::SendMessageRequest.new(
            id: SecureRandom.uuid,
            params: request
          )
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          payload, modified_kwargs = apply_interceptors(
            "message/send",
            rpc_request.to_h,
            modified_kwargs,
            context
          )
          response_data = send_request(payload, modified_kwargs)
          response = parse_response(response_data, Types::SendMessageSuccessResponse, Types::JSONRPCErrorResponse)
          raise JSONRPCError.new(response.error) if response.is_a?(Types::JSONRPCErrorResponse)

          deserialize_result(response.result)
        end

        # Sends a streaming message request to the agent and yields responses as they arrive.
        #
        # @param request [Types::MessageSendParams] The message send parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Enumerator] An enumerator yielding Message, Task, TaskStatusUpdateEvent, or TaskArtifactUpdateEvent
        def send_message_streaming(request:, context: nil, extensions: nil)
          rpc_request = Types::SendStreamingMessageRequest.new(
            id: SecureRandom.uuid,
            params: request
          )
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          payload, modified_kwargs = apply_interceptors(
            "message/stream",
            rpc_request.to_h,
            modified_kwargs,
            context
          )

          # Set headers for SSE
          headers = modified_kwargs[:headers] || {}
          headers["Accept"] = "text/event-stream"
          modified_kwargs[:headers] = headers

          # Create enumerator for streaming responses
          Enumerator.new do |yielder|
            begin
              response = @http_client.post(@url) do |req|
                req.headers.merge!(modified_kwargs[:headers] || {})
                req.body = payload.to_json
                req.options.timeout = modified_kwargs[:timeout] if modified_kwargs[:timeout]
              end

              raise HTTPError.new(response.status, response.reason_phrase) unless response.success?

              # Parse SSE stream
              parse_sse_stream(response.body, yielder)
            rescue Faraday::TimeoutError => e
              raise TimeoutError.new("Client Request timed out: #{e.message}")
            rescue Faraday::ClientError, Faraday::ServerError => e
              raise HTTPError.new(e.response&.status || 503, "HTTP error: #{e.message}")
            rescue JSON::ParserError => e
              raise JSONError.new("JSON parse error: #{e.message}")
            rescue Faraday::Error => e
              raise HTTPError.new(503, "Network communication error: #{e.message}")
            end
          end
        end

        # Retrieves the current state and history of a specific task.
        #
        # @param request [Types::TaskQueryParams] The task query parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::Task] The task object
        def get_task(request:, context: nil, extensions: nil)
          rpc_request = Types::GetTaskRequest.new(
            id: SecureRandom.uuid,
            params: request
          )
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          payload, modified_kwargs = apply_interceptors(
            "tasks/get",
            rpc_request.to_h,
            modified_kwargs,
            context
          )
          response_data = send_request(payload, modified_kwargs)
          response = parse_response(response_data, Types::GetTaskSuccessResponse, Types::JSONRPCErrorResponse)
          raise JSONRPCError.new(response.error) if response.is_a?(Types::JSONRPCErrorResponse)

          Types::Task.new(response.result)
        end

        # Requests the agent to cancel a specific task.
        #
        # @param request [Types::TaskIdParams] The task ID parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::Task] The updated task object
        def cancel_task(request:, context: nil, extensions: nil)
          rpc_request = Types::CancelTaskRequest.new(
            id: SecureRandom.uuid,
            params: request
          )
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          payload, modified_kwargs = apply_interceptors(
            "tasks/cancel",
            rpc_request.to_h,
            modified_kwargs,
            context
          )
          response_data = send_request(payload, modified_kwargs)
          response = parse_response(response_data, Types::CancelTaskSuccessResponse, Types::JSONRPCErrorResponse)
          raise JSONRPCError.new(response.error) if response.is_a?(Types::JSONRPCErrorResponse)

          Types::Task.new(response.result)
        end

        # Sets or updates the push notification configuration for a specific task.
        #
        # @param request [Types::TaskPushNotificationConfig] The push notification config
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::TaskPushNotificationConfig] The created or updated config
        def set_task_callback(request:, context: nil, extensions: nil)
          rpc_request = Types::SetTaskPushNotificationConfigRequest.new(
            id: SecureRandom.uuid,
            params: request
          )
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          payload, modified_kwargs = apply_interceptors(
            "tasks/pushNotificationConfig/set",
            rpc_request.to_h,
            modified_kwargs,
            context
          )
          response_data = send_request(payload, modified_kwargs)
          response = parse_response(response_data, Types::SetTaskPushNotificationConfigSuccessResponse, Types::JSONRPCErrorResponse)
          raise JSONRPCError.new(response.error) if response.is_a?(Types::JSONRPCErrorResponse)

          Types::TaskPushNotificationConfig.new(response.result)
        end

        # Retrieves the push notification configuration for a specific task.
        #
        # @param request [Types::GetTaskPushNotificationConfigParams] The query parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::TaskPushNotificationConfig] The push notification config
        def get_task_callback(request:, context: nil, extensions: nil)
          rpc_request = Types::GetTaskPushNotificationConfigRequest.new(
            id: SecureRandom.uuid,
            params: request
          )
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          payload, modified_kwargs = apply_interceptors(
            "tasks/pushNotificationConfig/get",
            rpc_request.to_h,
            modified_kwargs,
            context
          )
          response_data = send_request(payload, modified_kwargs)
          response = parse_response(response_data, Types::GetTaskPushNotificationConfigSuccessResponse, Types::JSONRPCErrorResponse)
          raise JSONRPCError.new(response.error) if response.is_a?(Types::JSONRPCErrorResponse)

          Types::TaskPushNotificationConfig.new(response.result)
        end

        # Reconnects to get task updates.
        #
        # @param request [Types::TaskIdParams] The task ID parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Enumerator] An enumerator yielding Task, Message, TaskStatusUpdateEvent, or TaskArtifactUpdateEvent
        def resubscribe(request:, context: nil, extensions: nil)
          rpc_request = Types::TaskResubscriptionRequest.new(
            id: SecureRandom.uuid,
            params: request
          )
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          payload, modified_kwargs = apply_interceptors(
            "tasks/resubscribe",
            rpc_request.to_h,
            modified_kwargs,
            context
          )

          # Set headers for SSE
          headers = modified_kwargs[:headers] || {}
          headers["Accept"] = "text/event-stream"
          modified_kwargs[:headers] = headers

          # Create enumerator for streaming responses
          Enumerator.new do |yielder|
            begin
              response = @http_client.post(@url) do |req|
                req.headers.merge!(modified_kwargs[:headers] || {})
                req.body = payload.to_json
                req.options.timeout = modified_kwargs[:timeout] if modified_kwargs[:timeout]
              end

              raise HTTPError.new(response.status, response.reason_phrase) unless response.success?

              # Parse SSE stream
              parse_sse_stream(response.body, yielder)
            rescue Faraday::TimeoutError => e
              raise TimeoutError.new("Client Request timed out: #{e.message}")
            rescue Faraday::ClientError, Faraday::ServerError => e
              raise HTTPError.new(e.response&.status || 503, "HTTP error: #{e.message}")
            rescue JSON::ParserError => e
              raise JSONError.new("JSON parse error: #{e.message}")
            rescue Faraday::Error => e
              raise HTTPError.new(503, "Network communication error: #{e.message}")
            end
          end
        end

        # Retrieves the AgentCard.
        #
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @param signature_verifier [Proc, nil] A callable used to verify the agent card's signatures
        # @return [Types::AgentCard] The agent card
        def get_card(context: nil, extensions: nil, signature_verifier: nil)
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          card = @agent_card

          unless card
            resolver = CardResolver.new(@http_client, @url)
            card = resolver.get_agent_card(
              http_kwargs: modified_kwargs,
              signature_verifier: signature_verifier
            )
            @needs_extended_card = card.supports_authenticated_extended_card
            @agent_card = card
          end

          return card unless @needs_extended_card

          request = Types::GetAuthenticatedExtendedCardRequest.new(id: SecureRandom.uuid)
          payload, modified_kwargs = apply_interceptors(
            request.method,
            request.to_h,
            modified_kwargs,
            context
          )
          response_data = send_request(payload, modified_kwargs)
          response = parse_response(response_data, Types::GetAuthenticatedExtendedCardSuccessResponse, Types::JSONRPCErrorResponse)
          raise JSONRPCError.new(response.error) if response.is_a?(Types::JSONRPCErrorResponse)

          card = Types::AgentCard.new(response.result)
          signature_verifier&.call(card)

          @agent_card = card
          @needs_extended_card = false
          card
        end

        # Closes the transport.
        def close
          # Faraday connections don't need explicit closing in the same way as httpx
          # But we can clear references if needed
          @http_client = nil
        end

        private

        def apply_interceptors(method_name, request_payload, http_kwargs, context)
          final_http_kwargs = http_kwargs || {}
          final_request_payload = request_payload

          @interceptors.each do |interceptor|
            final_request_payload, final_http_kwargs = interceptor.intercept(
              method_name,
              final_request_payload,
              final_http_kwargs,
              @agent_card,
              context
            )
          end
          [final_request_payload, final_http_kwargs]
        end

        def get_http_args(context)
          context&.state&.dig("http_kwargs")
        end

        def send_request(rpc_request_payload, http_kwargs = nil)
          begin
            response = @http_client.post(@url) do |req|
              req.headers["Content-Type"] = "application/json"
              req.headers.merge!(http_kwargs[:headers] || {}) if http_kwargs
              req.body = rpc_request_payload.to_json
              req.options.timeout = http_kwargs[:timeout] if http_kwargs&.dig(:timeout)
            end

            raise HTTPError.new(response.status, response.reason_phrase || "HTTP Error") unless response.success?

            JSON.parse(response.body)
          rescue Faraday::TimeoutError, Timeout::Error => e
            raise TimeoutError.new("Client Request timed out: #{e.message}")
          rescue Faraday::ClientError, Faraday::ServerError => e
            raise HTTPError.new(e.response&.status || 503, "HTTP error: #{e.message}")
          rescue JSON::ParserError => e
            raise JSONError.new("JSON parse error: #{e.message}")
          rescue Faraday::Error => e
            # Check if it's a timeout error
            if e.message.include?("timeout") || e.message.include?("execution expired")
              raise TimeoutError.new("Client Request timed out: #{e.message}")
            end
            raise HTTPError.new(503, "Network communication error: #{e.message}")
          end
        end

        def parse_response(response_data, success_class, error_class)
          # Check if it's an error response
          if response_data.key?("error")
            error_class.new(response_data)
          else
            success_class.new(response_data)
          end
        end

        def deserialize_result(result)
          # Result can be a Task or Message
          if result.is_a?(Hash)
            if result["kind"] == "task" || result.key?("id") && result.key?("contextId")
              Types::Task.new(result)
            elsif result["kind"] == "message" || result.key?("messageId")
              Types::Message.new(result)
            elsif result["kind"] == "status-update"
              Types::TaskStatusUpdateEvent.new(result)
            elsif result["kind"] == "artifact-update"
              Types::TaskArtifactUpdateEvent.new(result)
            else
              result
            end
          else
            result
          end
        end

        def parse_sse_stream(body, yielder)
          # Simple SSE parser - splits on double newlines and extracts data
          events = body.split(/\n\n+/)
          events.each do |event_text|
            next if event_text.strip.empty?

            # Extract data from SSE format (data: {...})
            data_line = event_text.lines.find { |line| line.start_with?("data:") }
            next unless data_line

            json_data = data_line.sub(/^data:\s*/, "").strip
            next if json_data.empty?

            begin
              response_data = JSON.parse(json_data)
              response = parse_response(response_data, Types::SendStreamingMessageSuccessResponse, Types::JSONRPCErrorResponse)
              raise JSONRPCError.new(response.error) if response.is_a?(Types::JSONRPCErrorResponse)

              result = deserialize_result(response.result)
              yielder << result
            rescue JSON::ParserError => e
              raise JSONError.new("Invalid SSE data format: #{e.message}")
            end
          end
        end

        def update_extension_header(http_kwargs, extensions)
          return http_kwargs || {} if extensions.nil? || extensions.empty?

          modified_kwargs = (http_kwargs || {}).dup
          headers = (modified_kwargs[:headers] || {}).dup
          headers["X-A2A-Extensions"] = extensions.join(",")
          modified_kwargs[:headers] = headers
          modified_kwargs
        end
      end
    end
  end
end
