# frozen_string_literal: true

require_relative "../middleware"
require_relative "credential_service"
require_relative "../../types"

module A2a
  module Client
    module Auth
      # An interceptor that automatically adds authentication details to requests.
      #
      # Based on the agent's security schemes.
      class Interceptor < CallInterceptor
        def initialize(credential_service:)
          @credential_service = credential_service
        end

        # Applies authentication headers to the request if credentials are available.
        #
        # @param method_name [String] The name of the RPC method
        # @param request_payload [Hash] The JSON RPC request payload dictionary
        # @param http_kwargs [Hash] The keyword arguments for the HTTP request
        # @param agent_card [Types::AgentCard, nil] The AgentCard associated with the client
        # @param context [CallContext, nil] The CallContext for this specific call
        # @return [Array<Hash, Hash>] A tuple containing the (potentially modified) request_payload and http_kwargs
        def intercept(_method_name, request_payload, http_kwargs, agent_card = nil, context = nil)
          return [request_payload, http_kwargs] unless agent_card
          return [request_payload, http_kwargs] unless agent_card.security
          return [request_payload, http_kwargs] unless agent_card.security_schemes

          # Process each security requirement
          # Security is an array of hashes, where each hash maps scheme names to lists
          agent_card.security.each do |requirement|
            # Handle both string and symbol keys
            requirement = requirement.transform_keys(&:to_s) if requirement.is_a?(Hash)
            requirement.each_key do |scheme_name|
              scheme_name = scheme_name.to_s
              credential = @credential_service.get_credentials(scheme_name, context)
              next unless credential
              next unless agent_card.security_schemes

              # Handle both string and symbol keys in security_schemes
              scheme_def_union = agent_card.security_schemes[scheme_name] || agent_card.security_schemes[scheme_name.to_sym]
              next unless scheme_def_union

              # Handle SecurityScheme wrapper
              scheme_def = if scheme_def_union.is_a?(Types::SecurityScheme)
                             scheme_def_union.root
                           else
                             scheme_def_union
                           end

              # Normalize headers - Faraday accepts both string and symbol keys
              headers = http_kwargs[:headers] || http_kwargs["headers"] || {}
              headers = headers.dup if headers.is_a?(Hash)

              # Case 1a: HTTP Bearer scheme
              if scheme_def.is_a?(Types::HTTPAuthSecurityScheme) && scheme_def.scheme&.downcase == "bearer"
                headers["Authorization"] = "Bearer #{credential}"
                http_kwargs[:headers] = headers
                return [request_payload, http_kwargs]
              end

              # Case 1b: OAuth2 and OIDC schemes, which are implicitly Bearer
              if scheme_def.is_a?(Types::OAuth2SecurityScheme) || scheme_def.is_a?(Types::OpenIdConnectSecurityScheme)
                headers["Authorization"] = "Bearer #{credential}"
                http_kwargs[:headers] = headers
                return [request_payload, http_kwargs]
              end

              # Case 2: API Key in Header
              next unless scheme_def.is_a?(Types::APIKeySecurityScheme) && scheme_def.in_ == Types::In::HEADER

              headers[scheme_def.name] = credential
              http_kwargs[:headers] = headers
              return [request_payload, http_kwargs]

              # NOTE: Other cases like API keys in query/cookie are not handled and will be skipped.
            end
          end

          [request_payload, http_kwargs]
        end
      end
    end
  end
end
