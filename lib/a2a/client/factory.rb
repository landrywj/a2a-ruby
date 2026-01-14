# frozen_string_literal: true

require "faraday"
require_relative "transports"
require_relative "base_client"

module A2a
  module Client
    # ClientFactory is used to generate the appropriate client for the agent.
    #
    # The factory is configured with a Config and optionally a list of
    # consumers to use for all generated Clients. The expected use is:
    #
    #   factory = Client::Factory.new(config, consumers)
    #   # Optionally register custom client implementations
    #   factory.register('my_custom_transport', custom_transport_producer)
    #   # Then with an agent card make a client with additional consumers and
    #   # interceptors
    #   client = factory.create(card, additional_consumers, interceptors)
    #
    # Now the client can be used consistently regardless of the transport. This
    # aligns the client configuration with the server's capabilities.
    # rubocop:disable Metrics/ClassLength
    class Factory
      # Transport producer is a callable that takes (card, url, config, interceptors)
      # and returns a ClientTransport
      # @type TransportProducer = Proc

      attr_reader :config, :consumers, :registry

      # @param config [Config] The client configuration
      # @param consumers [Array] A list of consumers to use for all generated clients
      def initialize(config, consumers: [])
        @config = config
        @consumers = consumers || []
        @registry = {}
        register_defaults(@config.supported_transports)
      end

      # Register a new transport producer for a given transport label.
      #
      # @param label [String] The transport protocol label
      # @param generator [Proc] A callable that produces a transport instance
      def register(label, generator)
        @registry[label.to_s] = generator
      end

      # Create a new Client for the provided AgentCard.
      #
      # @param card [Types::AgentCard] An AgentCard defining the characteristics of the agent
      # @param consumers [Array, nil] A list of consumers to pass responses to
      # @param interceptors [Array<CallInterceptor>, nil] A list of interceptors to use for each request
      # @param extensions [Array<String>, nil] List of extensions to be activated
      # @return [Base] A Client object
      # @raise [ArgumentError] If there is no valid matching of the client configuration with the
      #   server configuration
      def create(card:, consumers: nil, interceptors: nil, extensions: nil)
        transport_protocol, transport_url = select_transport(card)
        validate_transport(transport_protocol)

        merge_consumers(consumers)
        merge_extensions(extensions)

        transport = @registry[transport_protocol.to_s].call(card, transport_url, @config, interceptors || [])

        BaseClient.new(
          card: card,
          config: @config,
          transport: transport,
          consumers: merge_consumers(consumers),
          middleware: interceptors || []
        )
      end

      # Convenience method for constructing a client.
      #
      # Constructs a client that connects to the specified agent. Note that
      # creating multiple clients via this method is less efficient than
      # constructing an instance of Factory and reusing that.
      #
      # @param agent [String, Types::AgentCard] The base URL of the agent, or the AgentCard to connect to
      # @param client_config [Config, nil] The Config to use when connecting to the agent
      # @param consumers [Array, nil] A list of consumers to pass responses to
      # @param interceptors [Array<CallInterceptor>, nil] A list of interceptors to use for each request
      # @param relative_card_path [String, nil] If the agent field is a URL, this value is used as
      #   the relative path when resolving the agent card
      # @param resolver_http_kwargs [Hash, nil] Dictionary of arguments to provide to the HTTP
      #   client when resolving the agent card
      # @param extra_transports [Hash, nil] Additional transport protocols to enable when
      #   constructing the client
      # @param extensions [Array<String>, nil] List of extensions to be activated
      # @param signature_verifier [Proc, nil] A callable used to verify the agent card's signatures
      # @return [Base] A Client object
      # rubocop:disable Metrics/ParameterLists
      def self.connect(
        agent:,
        client_config: nil,
        consumers: nil,
        interceptors: nil,
        relative_card_path: nil,
        resolver_http_kwargs: nil,
        extra_transports: nil,
        extensions: nil,
        signature_verifier: nil
      )
        client_config ||= Config.new
        card = if agent.is_a?(String)
                 http_client = client_config.httpx_client || Faraday.new
                 resolver = CardResolver.new(http_client, agent)
                 resolver.get_agent_card(
                   relative_card_path: relative_card_path,
                   http_kwargs: resolver_http_kwargs,
                   signature_verifier: signature_verifier
                 )
               else
                 agent
               end

        factory = new(client_config, consumers: consumers)
        extra_transports&.each do |label, generator|
          factory.register(label, generator)
        end
        factory.create(card: card, consumers: consumers, interceptors: interceptors, extensions: extensions)
      end
      # rubocop:enable Metrics/ParameterLists

      # Generates a minimal card to simplify bootstrapping client creation.
      #
      # This minimal card is not viable itself to interact with the remote agent.
      # Instead this is a shorthand way to take a known url and transport option
      # and interact with the get card endpoint of the agent server to get the
      # correct agent card. This pattern is necessary for gRPC based card access
      # as typically these servers won't expose a well known path card.
      #
      # @param url [String] The base URL of the agent
      # @param transports [Array<String>, nil] List of transport protocols to support
      # @return [Types::AgentCard] A minimal AgentCard
      def self.minimal_agent_card(url:, transports: nil)
        transports ||= []
        additional_interfaces = transports[1..]&.map do |transport|
          Types::AgentInterface.new(transport: transport, url: url)
        end || []

        card_attrs = {
          url: url,
          additional_interfaces: additional_interfaces,
          supports_authenticated_extended_card: true,
          capabilities: Types::AgentCapabilities.new,
          default_input_modes: [],
          default_output_modes: [],
          description: "",
          skills: [],
          version: "",
          name: ""
        }
        # Only set preferred_transport if we have transports, otherwise let AgentCard use its default
        card_attrs[:preferred_transport] = transports.first unless transports.empty?

        Types::AgentCard.new(card_attrs)
      end

      private

      def register_defaults(supported)
        # Empty support list implies JSON-RPC only.
        if supported.empty? || supported.include?(Types::TransportProtocol::JSONRPC)
          register(
            Types::TransportProtocol::JSONRPC,
            lambda do |card, url, config, interceptors|
              http_client = config.httpx_client || Faraday.new
              Transports::JSONRPC.new(
                http_client: http_client,
                agent_card: card,
                url: url,
                interceptors: interceptors || [],
                extensions: config.extensions
              )
            end
          )
        end

        if supported.include?(Types::TransportProtocol::HTTP_JSON)
          register(
            Types::TransportProtocol::HTTP_JSON,
            lambda do |_card, _url, _config, _interceptors|
              raise NotImplementedError, "REST transport not yet implemented. This will be implemented in Phase 5."
            end
          )
        end

        return unless supported.include?(Types::TransportProtocol::GRPC)

        register(
          Types::TransportProtocol::GRPC,
          lambda do |_card, _url, _config, _interceptors|
            raise NotImplementedError, "gRPC transport not yet implemented. This will be implemented in Phase 8."
          end
        )
      end

      def select_transport(card)
        server_set = build_server_set(card)
        client_set = build_client_set

        if @config.use_client_preference
          find_transport_by_client_preference(client_set, server_set)
        else
          find_transport_by_server_preference(client_set, server_set)
        end
      end

      def build_server_set(card)
        server_preferred = card.preferred_transport || Types::TransportProtocol::JSONRPC
        server_set = { server_preferred => card.url }
        card.additional_interfaces&.each do |interface|
          server_set[interface.transport] = interface.url
        end
        server_set
      end

      def build_client_set
        @config.supported_transports.empty? ? [Types::TransportProtocol::JSONRPC] : @config.supported_transports
      end

      def find_transport_by_client_preference(client_set, server_set)
        client_set.each do |transport|
          next unless server_set.key?(transport)

          return [transport, server_set[transport]]
        end
        [nil, nil]
      end

      def find_transport_by_server_preference(client_set, server_set)
        server_set.each do |transport, url|
          next unless client_set.include?(transport)

          return [transport, url]
        end
        [nil, nil]
      end

      def validate_transport(transport_protocol)
        raise ArgumentError, "no compatible transports found" unless transport_protocol
        raise ArgumentError, "no client available for #{transport_protocol}" unless @registry.key?(transport_protocol.to_s)
      end

      def merge_consumers(consumers)
        all_consumers = @consumers.dup
        all_consumers.concat(consumers) if consumers
        all_consumers
      end

      def merge_extensions(extensions)
        all_extensions = @config.extensions.dup
        if extensions
          all_extensions.concat(extensions)
          @config.extensions = all_extensions
        end
        all_extensions
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
