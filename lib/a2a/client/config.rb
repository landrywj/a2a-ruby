# frozen_string_literal: true

module A2a
  module Client
    # Configuration class for the A2A Client Factory
    class Config
      attr_accessor :streaming, :polling, :httpx_client, :grpc_channel_factory,
                    :supported_transports, :use_client_preference, :accepted_output_modes,
                    :push_notification_configs, :extensions

      # @param streaming [Boolean] Whether client supports streaming (default: true)
      # @param polling [Boolean] Whether client prefers to poll for updates from message:send (default: false)
      # @param httpx_client [Object] HTTP client to use to connect to agent (default: nil)
      # @param grpc_channel_factory [Proc, nil] Generates a grpc connection channel for a given url (default: nil)
      # @param supported_transports [Array<String, Types::TransportProtocol>] Ordered list of transports
      #   for connecting to agent (in order of preference). Empty implies JSONRPC only.
      # @param use_client_preference [Boolean] Whether to use client transport preferences over server preferences.
      #   Recommended to use server preferences in most situations (default: false)
      # @param accepted_output_modes [Array<String>] The set of accepted output modes for the client (default: [])
      # @param push_notification_configs [Array] Push notification callbacks to use for every request (default: [])
      # @param extensions [Array<String>] A list of extension URIs the client supports (default: [])
      # rubocop:disable Metrics/ParameterLists
      def initialize(
        streaming: true,
        polling: false,
        httpx_client: nil,
        grpc_channel_factory: nil,
        supported_transports: [],
        use_client_preference: false,
        accepted_output_modes: [],
        push_notification_configs: [],
        extensions: []
      )
        @streaming = streaming
        @polling = polling
        @httpx_client = httpx_client
        @grpc_channel_factory = grpc_channel_factory
        @supported_transports = supported_transports
        @use_client_preference = use_client_preference
        @accepted_output_modes = accepted_output_modes
        @push_notification_configs = push_notification_configs
        @extensions = extensions
      end
      # rubocop:enable Metrics/ParameterLists
    end
  end
end
