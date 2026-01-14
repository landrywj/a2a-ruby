# frozen_string_literal: true

require_relative "base"
require_relative "enums"

module A2a
  module Types
    # Defines a security scheme using an API key.
    class APIKeySecurityScheme < BaseModel
      attr_accessor :type, :name, :in_, :description

      def initialize(attributes = {})
        super
        @type = attributes[:type] || attributes["type"] || "apiKey"
        @name = attributes[:name] || attributes["name"]
        @in_ = attributes[:in_] || attributes["in"] || attributes["in_"]
        @description = attributes[:description] || attributes["description"]
      end

      def to_h
        hash = super
        hash["in"] = hash.delete("in_") if hash.key?("in_")
        hash
      end
    end

    # Defines a security scheme using HTTP authentication.
    class HTTPAuthSecurityScheme < BaseModel
      attr_accessor :type, :scheme, :bearer_format, :description

      def initialize(attributes = {})
        super
        @type = attributes[:type] || attributes["type"] || "http"
        @scheme = attributes[:scheme] || attributes["scheme"]
        @bearer_format = attributes[:bearer_format] || attributes["bearerFormat"]
        @description = attributes[:description] || attributes["description"]
      end

      def to_h
        hash = super
        hash["bearerFormat"] = hash.delete("bearer_format") if hash.key?("bearer_format")
        hash
      end
    end

    # Defines configuration details for OAuth 2.0 flows.
    class OAuthFlows < BaseModel
      attr_accessor :implicit, :password, :client_credentials, :authorization_code

      def initialize(attributes = {})
        super
        @implicit = attributes[:implicit] || attributes["implicit"]
        @password = attributes[:password] || attributes["password"]
        @client_credentials = attributes[:client_credentials] || attributes["clientCredentials"]
        @authorization_code = attributes[:authorization_code] || attributes["authorizationCode"]
      end

      def to_h
        hash = super
        hash["clientCredentials"] = hash.delete("client_credentials") if hash.key?("client_credentials")
        hash["authorizationCode"] = hash.delete("authorization_code") if hash.key?("authorization_code")
        hash
      end
    end

    # Defines a security scheme using OAuth 2.0.
    class OAuth2SecurityScheme < BaseModel
      attr_accessor :type, :flows, :oauth2_metadata_url, :description

      def initialize(attributes = {})
        super
        @type = attributes[:type] || attributes["type"] || "oauth2"
        flows_data = attributes[:flows] || attributes["flows"]
        @flows = if flows_data
                   flows_data.is_a?(OAuthFlows) ? flows_data : OAuthFlows.new(flows_data)
                 end
        @oauth2_metadata_url = attributes[:oauth2_metadata_url] || attributes["oauth2MetadataUrl"]
        @description = attributes[:description] || attributes["description"]
      end

      def to_h
        hash = super
        hash["oauth2MetadataUrl"] = hash.delete("oauth2_metadata_url") if hash.key?("oauth2_metadata_url")
        hash
      end
    end

    # Defines a security scheme using OpenID Connect.
    class OpenIdConnectSecurityScheme < BaseModel
      attr_accessor :type, :open_id_connect_url, :description

      def initialize(attributes = {})
        super
        @type = attributes[:type] || attributes["type"] || "openIdConnect"
        @open_id_connect_url = attributes[:open_id_connect_url] || attributes["openIdConnectUrl"]
        @description = attributes[:description] || attributes["description"]
      end

      def to_h
        hash = super
        hash["openIdConnectUrl"] = hash.delete("open_id_connect_url") if hash.key?("open_id_connect_url")
        hash
      end
    end

    # Defines a security scheme using mTLS authentication.
    class MutualTLSSecurityScheme < BaseModel
      attr_accessor :type, :description

      def initialize(attributes = {})
        super
        @type = attributes[:type] || attributes["type"] || "mutualTLS"
        @description = attributes[:description] || attributes["description"]
      end
    end

    # Defines a security scheme that can be used to secure an agent's endpoints.
    # This is a discriminated union type based on the OpenAPI 3.0 Security Scheme Object.
    class SecurityScheme < BaseModel
      attr_accessor :root

      def initialize(attributes = {})
        super
        # Handle both direct assignment and hash-based initialization
        if attributes.is_a?(Hash)
          root_data = attributes[:root] || attributes["root"] || attributes
          @root = case root_data
                  when APIKeySecurityScheme, HTTPAuthSecurityScheme, OAuth2SecurityScheme,
                       OpenIdConnectSecurityScheme, MutualTLSSecurityScheme
                    root_data
                  when Hash
                    create_security_scheme_from_hash(root_data)
                  else
                    root_data
                  end
        else
          @root = attributes
        end
      end

      def to_h
        @root.to_h
      end

      private

      def create_security_scheme_from_hash(hash)
        type = hash[:type] || hash["type"]
        case type
        when "apiKey"
          APIKeySecurityScheme.new(hash)
        when "http"
          HTTPAuthSecurityScheme.new(hash)
        when "oauth2"
          OAuth2SecurityScheme.new(hash)
        when "openIdConnect"
          OpenIdConnectSecurityScheme.new(hash)
        when "mutualTLS"
          MutualTLSSecurityScheme.new(hash)
        else
          raise ArgumentError, "Unknown security scheme type: #{type}"
        end
      end
    end
  end
end
