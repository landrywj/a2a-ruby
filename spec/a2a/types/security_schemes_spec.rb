# frozen_string_literal: true

require "spec_helper"

RSpec.describe A2a::Types::APIKeySecurityScheme do
  describe "#initialize" do
    it "creates an API key security scheme with required fields" do
      scheme = described_class.new(
        name: "X-API-Key",
        in_: A2a::Types::In::HEADER
      )

      expect(scheme.type).to eq("apiKey")
      expect(scheme.name).to eq("X-API-Key")
      expect(scheme.in_).to eq(A2a::Types::In::HEADER)
    end

    it "handles camelCase JSON keys" do
      scheme = described_class.new(
        "name" => "X-API-Key",
        "in" => A2a::Types::In::HEADER,
        "description" => "API Key authentication"
      )

      expect(scheme.name).to eq("X-API-Key")
      expect(scheme.in_).to eq(A2a::Types::In::HEADER)
      expect(scheme.description).to eq("API Key authentication")
    end

    it "converts to hash with correct key format" do
      scheme = described_class.new(
        name: "X-API-Key",
        in_: A2a::Types::In::HEADER
      )

      hash = scheme.to_h
      expect(hash["in"]).to eq(A2a::Types::In::HEADER)
      expect(hash.key?("in_")).to be false
    end
  end
end

RSpec.describe A2a::Types::HTTPAuthSecurityScheme do
  describe "#initialize" do
    it "creates an HTTP auth security scheme" do
      scheme = described_class.new(
        scheme: "bearer"
      )

      expect(scheme.type).to eq("http")
      expect(scheme.scheme).to eq("bearer")
    end

    it "handles bearer format" do
      scheme = described_class.new(
        scheme: "bearer",
        bearer_format: "JWT"
      )

      expect(scheme.bearer_format).to eq("JWT")
    end

    it "converts to hash with correct key format" do
      scheme = described_class.new(
        scheme: "bearer",
        bearer_format: "JWT"
      )

      hash = scheme.to_h
      expect(hash["bearerFormat"]).to eq("JWT")
      expect(hash.key?("bearer_format")).to be false
    end
  end
end

RSpec.describe A2a::Types::OAuth2SecurityScheme do
  describe "#initialize" do
    it "creates an OAuth2 security scheme" do
      flows = A2a::Types::OAuthFlows.new(
        authorization_code: {
          authorization_url: "https://example.com/auth",
          token_url: "https://example.com/token",
          scopes: { "read" => "Read scope" }
        }
      )

      scheme = described_class.new(
        flows: flows
      )

      expect(scheme.type).to eq("oauth2")
      expect(scheme.flows).to be_a(A2a::Types::OAuthFlows)
    end
  end
end

RSpec.describe A2a::Types::OpenIdConnectSecurityScheme do
  describe "#initialize" do
    it "creates an OpenID Connect security scheme" do
      scheme = described_class.new(
        open_id_connect_url: "https://example.com/.well-known/openid-configuration"
      )

      expect(scheme.type).to eq("openIdConnect")
      expect(scheme.open_id_connect_url).to eq("https://example.com/.well-known/openid-configuration")
    end
  end
end

RSpec.describe A2a::Types::MutualTLSSecurityScheme do
  describe "#initialize" do
    it "creates a mutual TLS security scheme" do
      scheme = described_class.new

      expect(scheme.type).to eq("mutualTLS")
    end
  end
end

RSpec.describe A2a::Types::SecurityScheme do
  describe "#initialize" do
    it "wraps an APIKeySecurityScheme" do
      api_key = A2a::Types::APIKeySecurityScheme.new(
        name: "X-API-Key",
        in_: A2a::Types::In::HEADER
      )

      scheme = described_class.new(root: api_key)

      expect(scheme.root).to eq(api_key)
      expect(scheme.root).to be_a(A2a::Types::APIKeySecurityScheme)
    end

    it "creates from hash with type" do
      scheme = described_class.new(
        "type" => "apiKey",
        "name" => "X-API-Key",
        "in" => A2a::Types::In::HEADER
      )

      expect(scheme.root).to be_a(A2a::Types::APIKeySecurityScheme)
      expect(scheme.root.name).to eq("X-API-Key")
    end

    it "creates HTTP auth scheme from hash" do
      scheme = described_class.new(
        "type" => "http",
        "scheme" => "bearer"
      )

      expect(scheme.root).to be_a(A2a::Types::HTTPAuthSecurityScheme)
      expect(scheme.root.scheme).to eq("bearer")
    end

    it "creates OAuth2 scheme from hash" do
      scheme = described_class.new(
        "type" => "oauth2",
        "flows" => {
          "authorizationCode" => {
            "authorizationUrl" => "https://example.com/auth",
            "tokenUrl" => "https://example.com/token",
            "scopes" => { "read" => "Read scope" }
          }
        }
      )

      expect(scheme.root).to be_a(A2a::Types::OAuth2SecurityScheme)
    end

    it "raises error for unknown type" do
      expect {
        described_class.new("type" => "unknown")
      }.to raise_error(ArgumentError, /Unknown security scheme type/)
    end
  end
end
