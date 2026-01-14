# frozen_string_literal: true

require "faraday"
require "json"
require_relative "base"
require_relative "../../types"
require_relative "../card_resolver"
require_relative "../errors"

module A2a
  module Client
    module Transports
      # A REST transport for the A2A client.
      # rubocop:disable Metrics/ClassLength
      class REST < Base
        attr_reader :url, :agent_card, :interceptors, :extensions, :http_client

        # Initializes the REST transport.
        #
        # @param http_client [Faraday::Connection] An HTTP client instance
        # @param agent_card [Types::AgentCard, nil] The agent card
        # @param url [String, nil] The URL to connect to
        # @param interceptors [Array<CallInterceptor>] A list of interceptors
        # @param extensions [Array<String>, nil] List of extensions to activate
        # rubocop:disable Lint/MissingSuper
        def initialize(http_client:, agent_card: nil, url: nil, interceptors: [], extensions: nil)
          @url = (url || agent_card&.url)&.chomp("/")
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
          payload = prepare_send_message_payload(request)
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          payload, modified_kwargs = apply_interceptors("message/send", payload, modified_kwargs, context)

          response_data = send_post_request("/v1/message:send", payload, modified_kwargs)
          deserialize_task_or_message(response_data)
        end

        # Sends a streaming message request to the agent and yields responses as they arrive.
        #
        # @param request [Types::MessageSendParams] The message send parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Enumerator] An enumerator yielding Message, Task, TaskStatusUpdateEvent, or TaskArtifactUpdateEvent
        # rubocop:disable Metrics/AbcSize
        def send_message_streaming(request:, context: nil, extensions: nil)
          payload = prepare_send_message_payload(request)
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          payload, modified_kwargs = apply_interceptors("message/stream", payload, modified_kwargs, context)

          # Set headers for SSE
          headers = modified_kwargs[:headers] || {}
          headers["Accept"] = "text/event-stream"
          modified_kwargs[:headers] = headers

          # Create enumerator for streaming responses
          Enumerator.new do |yielder|
            response = @http_client.post("#{@url}/v1/message:stream") do |req|
              req.headers["Content-Type"] = "application/json"
              req.headers.merge!(modified_kwargs[:headers] || {})
              req.body = payload.to_json
              req.options.timeout = modified_kwargs[:timeout] if modified_kwargs[:timeout]
            end

            raise HTTPError.new(response.status, response.reason_phrase) unless response.success?

            # Parse SSE stream
            parse_sse_stream(response.body, yielder)
          rescue Faraday::TimeoutError => e
            raise TimeoutError, "Client Request timed out: #{e.message}"
          rescue Faraday::ClientError, Faraday::ServerError => e
            raise HTTPError.new(e.response&.status || 503, "HTTP error: #{e.message}")
          rescue JSON::ParserError => e
            raise JSONError, "JSON parse error: #{e.message}"
          rescue Faraday::Error => e
            raise HTTPError.new(503, "Network communication error: #{e.message}")
          end
        end
        # rubocop:enable Metrics/AbcSize

        # Retrieves the current state and history of a specific task.
        #
        # @param request [Types::TaskQueryParams] The task query parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::Task] The task object
        def get_task(request:, context: nil, extensions: nil)
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          query_params = {}
          query_params["historyLength"] = request.history_length.to_s if request.history_length

          # Apply interceptors (REST doesn't use method name for interceptors in the same way)
          _, modified_kwargs = apply_interceptors("tasks/get", {}, modified_kwargs, context)

          response_data = send_get_request("/v1/tasks/#{request.id}", query_params, modified_kwargs)
          Types::Task.new(response_data)
        end

        # Requests the agent to cancel a specific task.
        #
        # @param request [Types::TaskIdParams] The task ID parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::Task] The updated task object
        def cancel_task(request:, context: nil, extensions: nil)
          # REST uses POST with empty body or CancelTaskRequest format
          payload = { "name" => "tasks/#{request.id}" }
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          payload, modified_kwargs = apply_interceptors("tasks/cancel", payload, modified_kwargs, context)

          response_data = send_post_request("/v1/tasks/#{request.id}:cancel", payload, modified_kwargs)
          Types::Task.new(response_data)
        end

        # Sets or updates the push notification configuration for a specific task.
        #
        # @param request [Types::TaskPushNotificationConfig] The push notification config
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::TaskPushNotificationConfig] The created or updated config
        def set_task_callback(request:, context: nil, extensions: nil)
          payload = {
            "parent" => "tasks/#{request.task_id}",
            "configId" => request.push_notification_config.id,
            "config" => request.push_notification_config.to_h
          }
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          payload, modified_kwargs = apply_interceptors("tasks/pushNotificationConfig/set", payload, modified_kwargs, context)

          response_data = send_post_request("/v1/tasks/#{request.task_id}/pushNotificationConfigs", payload, modified_kwargs)
          # Response is a TaskPushNotificationConfig with both task_id and push_notification_config
          Types::TaskPushNotificationConfig.new(response_data)
        end

        # Retrieves the push notification configuration for a specific task.
        #
        # @param request [Types::GetTaskPushNotificationConfigParams] The query parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Types::TaskPushNotificationConfig] The push notification config
        def get_task_callback(request:, context: nil, extensions: nil)
          raise ArgumentError, "push_notification_config_id is required" unless request.push_notification_config_id

          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          _, modified_kwargs = apply_interceptors("tasks/pushNotificationConfig/get", {}, modified_kwargs, context)

          response_data = send_get_request(
            "/v1/tasks/#{request.id}/pushNotificationConfigs/#{request.push_notification_config_id}",
            {},
            modified_kwargs
          )
          # Response might be just the config or a full TaskPushNotificationConfig
          # If it's just the config, wrap it
          if response_data.key?("taskId") || response_data.key?("pushNotificationConfig")
            Types::TaskPushNotificationConfig.new(response_data)
          else
            Types::TaskPushNotificationConfig.new(
              task_id: request.id,
              push_notification_config: Types::PushNotificationConfig.new(response_data)
            )
          end
        end

        # Reconnects to get task updates.
        #
        # @param request [Types::TaskIdParams] The task ID parameters
        # @param context [CallContext, nil] The client call context
        # @param extensions [Array<String>, nil] List of extensions to activate
        # @return [Enumerator] An enumerator yielding Task, Message, TaskStatusUpdateEvent, or TaskArtifactUpdateEvent
        # rubocop:disable Metrics/AbcSize
        def resubscribe(request:, context: nil, extensions: nil)
          modified_kwargs = update_extension_header(get_http_args(context), extensions || @extensions)
          modified_kwargs[:timeout] = nil # Allow long-running connections
          _, modified_kwargs = apply_interceptors("tasks/resubscribe", {}, modified_kwargs, context)

          # Set headers for SSE
          headers = modified_kwargs[:headers] || {}
          headers["Accept"] = "text/event-stream"
          modified_kwargs[:headers] = headers

          # Create enumerator for streaming responses
          Enumerator.new do |yielder|
            response = @http_client.get("#{@url}/v1/tasks/#{request.id}:subscribe") do |req|
              req.headers.merge!(modified_kwargs[:headers] || {})
              req.params.merge!(modified_kwargs[:params] || {}) if modified_kwargs[:params]
              req.options.timeout = modified_kwargs[:timeout] if modified_kwargs[:timeout]
            end

            raise HTTPError.new(response.status, response.reason_phrase) unless response.success?

            # Parse SSE stream
            parse_sse_stream(response.body, yielder)
          rescue Faraday::TimeoutError => e
            raise TimeoutError, "Client Request timed out: #{e.message}"
          rescue Faraday::ClientError, Faraday::ServerError => e
            raise HTTPError.new(e.response&.status || 503, "HTTP error: #{e.message}")
          rescue JSON::ParserError => e
            raise JSONError, "JSON parse error: #{e.message}"
          rescue Faraday::Error => e
            raise HTTPError.new(503, "Network communication error: #{e.message}")
          end
        end
        # rubocop:enable Metrics/AbcSize

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

          _, modified_kwargs = apply_interceptors("card/get", {}, modified_kwargs, context)
          response_data = send_get_request("/v1/card", {}, modified_kwargs)
          card = Types::AgentCard.new(response_data)
          signature_verifier&.call(card)

          @agent_card = card
          @needs_extended_card = false
          card
        end
        # rubocop:enable Lint/MissingSuper

        # Closes the transport.
        def close
          # Faraday connections don't need explicit closing in the same way as httpx
          # But we can clear references if needed
          @http_client = nil
        end

        private

        def prepare_send_message_payload(request)
          # Convert MessageSendParams to protobuf JSON format
          # SendMessageRequest has: request (Message), configuration, metadata
          payload = {}
          payload["request"] = request.message.to_h if request.message
          payload["configuration"] = request.configuration.to_h if request.configuration
          payload["metadata"] = request.metadata if request.metadata
          payload
        end

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

        # rubocop:disable Metrics/AbcSize
        def send_post_request(path, payload, http_kwargs = nil)
          response = @http_client.post("#{@url}#{path}") do |req|
            req.headers["Content-Type"] = "application/json"
            req.headers.merge!(http_kwargs[:headers] || {}) if http_kwargs
            req.body = payload.to_json
            req.options.timeout = http_kwargs[:timeout] if http_kwargs&.dig(:timeout)
          end

          raise HTTPError.new(response.status, response.reason_phrase || "HTTP Error") unless response.success?

          JSON.parse(response.body)
        rescue Faraday::TimeoutError, Timeout::Error => e
          raise TimeoutError, "Client Request timed out: #{e.message}"
        rescue Faraday::ClientError, Faraday::ServerError => e
          raise HTTPError.new(e.response&.status || 503, "HTTP error: #{e.message}")
        rescue JSON::ParserError => e
          raise JSONError, "JSON parse error: #{e.message}"
        rescue Faraday::Error => e
          # Check if it's a timeout error
          raise TimeoutError, "Client Request timed out: #{e.message}" if e.message.include?("timeout") || e.message.include?("execution expired")

          raise HTTPError.new(503, "Network communication error: #{e.message}")
        end

        def send_get_request(path, query_params, http_kwargs = nil)
          response = @http_client.get("#{@url}#{path}") do |req|
            req.headers.merge!(http_kwargs[:headers] || {}) if http_kwargs
            query_params.each { |k, v| req.params[k] = v }
            req.options.timeout = http_kwargs[:timeout] if http_kwargs&.dig(:timeout)
          end

          raise HTTPError.new(response.status, response.reason_phrase || "HTTP Error") unless response.success?

          JSON.parse(response.body)
        rescue Faraday::TimeoutError, Timeout::Error => e
          raise TimeoutError, "Client Request timed out: #{e.message}"
        rescue Faraday::ClientError, Faraday::ServerError => e
          raise HTTPError.new(e.response&.status || 503, "HTTP error: #{e.message}")
        rescue JSON::ParserError => e
          raise JSONError, "JSON parse error: #{e.message}"
        rescue Faraday::Error => e
          # Check if it's a timeout error
          raise TimeoutError, "Client Request timed out: #{e.message}" if e.message.include?("timeout") || e.message.include?("execution expired")

          raise HTTPError.new(503, "Network communication error: #{e.message}")
        end

        def deserialize_task_or_message(response_data)
          # Response can be Task or Message
          if response_data.is_a?(Hash)
            if response_data["kind"] == "task" || (response_data.key?("id") && response_data.key?("contextId"))
              Types::Task.new(response_data)
            elsif response_data["kind"] == "message" || response_data.key?("messageId")
              Types::Message.new(response_data)
            elsif response_data.key?("id") && response_data.key?("contextId")
              # Try to determine from structure
              Types::Task.new(response_data)
            elsif response_data.key?("messageId")
              Types::Message.new(response_data)
            else
              response_data
            end
          else
            response_data
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
              # REST SSE responses contain StreamResponse format
              # which has a result field that can be Task, Message, or Event
              result = deserialize_stream_response(response_data)
              yielder << result if result
            rescue JSON::ParserError => e
              raise JSONError, "Invalid SSE data format: #{e.message}"
            end
          end
        end

        def deserialize_stream_response(response_data)
          # StreamResponse format: { "result": <Task|Message|Event> }
          result = response_data["result"] || response_data
          return nil unless result

          if result.is_a?(Hash)
            if result["kind"] == "task" || (result.key?("id") && result.key?("contextId"))
              Types::Task.new(result)
            elsif result["kind"] == "message" || result.key?("messageId")
              Types::Message.new(result)
            elsif result["kind"] == "status-update"
              Types::TaskStatusUpdateEvent.new(result)
            elsif result["kind"] == "artifact-update"
              Types::TaskArtifactUpdateEvent.new(result)
            elsif result.key?("id") && result.key?("contextId")
              # Try to determine from structure
              Types::Task.new(result)
            elsif result.key?("messageId")
              Types::Message.new(result)
            else
              result
            end
          else
            result
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
        # rubocop:enable Metrics/AbcSize
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
