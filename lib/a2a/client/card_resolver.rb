# frozen_string_literal: true

require "faraday"
require "json"

module A2a
  module Client
    # Agent Card resolver.
    class CardResolver
      attr_reader :base_url, :agent_card_path, :http_client

      # Initializes the CardResolver.
      #
      # @param http_client [Faraday::Connection] An HTTP client instance (e.g., Faraday connection)
      # @param base_url [String] The base URL of the agent's host
      # @param agent_card_path [String] The path to the agent card endpoint, relative to the base URL
      def initialize(http_client, base_url, agent_card_path: Utils::Constants::AGENT_CARD_WELL_KNOWN_PATH)
        @base_url = base_url.to_s.sub(%r{/$}, "")
        @agent_card_path = agent_card_path.to_s.sub(%r{^/}, "")
        @http_client = http_client
      end

      # Fetches an agent card from a specified path relative to the base_url.
      #
      # If relative_card_path is nil, it defaults to the resolver's configured
      # agent_card_path (for the public agent card).
      #
      # @param relative_card_path [String, nil] Optional path to the agent card endpoint,
      #   relative to the base URL. If nil, uses the default public agent card path.
      #   Use '/' for an empty path.
      # @param http_kwargs [Hash, nil] Optional hash of keyword arguments to pass to the
      #   underlying HTTP request.
      # @param signature_verifier [Proc, nil] A callable used to verify the agent card's signatures
      # @return [Types::AgentCard] An AgentCard object representing the agent's capabilities
      # @raise [HTTPError] If an HTTP error occurs during the request
      # @raise [JSONError] If the response body cannot be decoded as JSON or validated
      def get_agent_card(relative_card_path: nil, http_kwargs: nil, signature_verifier: nil)
        path_segment = relative_card_path.nil? ? @agent_card_path : relative_card_path.to_s.sub(%r{^/}, "")
        target_url = "#{@base_url}/#{path_segment}"

        begin
          response = fetch_response(target_url, http_kwargs)
          validate_response(response, target_url)
          agent_card = parse_agent_card(response.body, target_url)
          signature_verifier&.call(agent_card)
          agent_card
        rescue HTTPError
          raise
        rescue Faraday::Error => e
          raise HTTPError.new(503, "Network communication error fetching agent card from #{target_url}: #{e.message}")
        rescue JSON::ParserError => e
          raise JSONError, "Failed to parse JSON for agent card from #{target_url}: #{e.message}"
        rescue StandardError => e
          raise JSONError, "Failed to validate agent card structure from #{target_url}: #{e.message}"
        end
      end

      private

      def fetch_response(target_url, http_kwargs)
        request_options = http_kwargs || {}
        return @http_client.get(target_url) if request_options.empty?

        @http_client.get(target_url) do |req|
          apply_request_options(req, request_options)
        end
      end

      def apply_request_options(req, request_options)
        request_options.each do |key, value|
          case key.to_s
          when "headers", :headers
            value.each { |h, v| req.headers[h.to_s] = v }
          when "params", :params
            req.params.merge!(value)
          else
            req.options[key] = value
          end
        end
      end

      def validate_response(response, target_url)
        return if (200..299).include?(response.status)

        raise HTTPError.new(response.status, "Failed to fetch agent card from #{target_url}")
      end

      def parse_agent_card(body, _target_url)
        agent_card_data = JSON.parse(body)
        Types::AgentCard.from_h(agent_card_data)
      end
    end
  end
end
