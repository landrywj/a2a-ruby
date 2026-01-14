# frozen_string_literal: true

require "spec_helper"

RSpec.describe A2a::Client::Auth::Interceptor do
  let(:credential_store) { A2a::Client::Auth::InMemoryContextCredentialStore.new }
  let(:interceptor) { described_class.new(credential_service: credential_store) }
  let(:session_id) { "session-123" }
  let(:context) { A2a::Client::CallContext.new(state: { "sessionId" => session_id }) }

  describe "#intercept" do
    context "when no agent card is provided" do
      it "returns unmodified request and kwargs" do
        request_payload = { "foo" => "bar" }
        http_kwargs = { "fizz" => "buzz" }

        new_payload, new_kwargs = interceptor.intercept(
          "message/send",
          request_payload,
          http_kwargs,
          nil,
          context
        )

        expect(new_payload).to eq(request_payload)
        expect(new_kwargs).to eq(http_kwargs)
      end
    end

    context "when agent card has no security" do
      it "returns unmodified request and kwargs" do
        agent_card = A2a::Types::AgentCard.new(
          name: "testbot",
          url: "http://example.com",
          default_input_modes: [],
          default_output_modes: []
        )

        request_payload = { "foo" => "bar" }
        http_kwargs = { "fizz" => "buzz" }

        new_payload, new_kwargs = interceptor.intercept(
          "message/send",
          request_payload,
          http_kwargs,
          agent_card,
          context
        )

        expect(new_payload).to eq(request_payload)
        expect(new_kwargs).to eq(http_kwargs)
      end
    end

    context "with API Key in header" do
      it "adds API key to headers" do
        credential = "secret-api-key"
        credential_store.set_credentials(session_id, "apikey", credential)

        agent_card = A2a::Types::AgentCard.new(
          name: "testbot",
          url: "http://example.com",
          default_input_modes: [],
          default_output_modes: [],
          security: [{ "apikey" => [] }],
          security_schemes: {
            "apikey" => A2a::Types::SecurityScheme.new(
              root: A2a::Types::APIKeySecurityScheme.new(
                name: "X-API-Key",
                in_: A2a::Types::In::HEADER
              )
            )
          }
        )

        request_payload = { "method" => "message/send" }
        http_kwargs = { headers: {} }

        _, new_kwargs = interceptor.intercept(
          "message/send",
          request_payload,
          http_kwargs,
          agent_card,
          context
        )

        expect(new_kwargs[:headers]["X-API-Key"]).to eq(credential)
      end
    end

    context "with HTTP Bearer authentication" do
      it "adds Bearer token to Authorization header" do
        credential = "bearer-token-123"
        credential_store.set_credentials(session_id, "bearer", credential)

        agent_card = A2a::Types::AgentCard.new(
          name: "testbot",
          url: "http://example.com",
          default_input_modes: [],
          default_output_modes: [],
          security: [{ "bearer" => [] }],
          security_schemes: {
            "bearer" => A2a::Types::SecurityScheme.new(
              root: A2a::Types::HTTPAuthSecurityScheme.new(
                scheme: "bearer"
              )
            )
          }
        )

        request_payload = { "method" => "message/send" }
        http_kwargs = { headers: {} }

        _, new_kwargs = interceptor.intercept(
          "message/send",
          request_payload,
          http_kwargs,
          agent_card,
          context
        )

        expect(new_kwargs[:headers]["Authorization"]).to eq("Bearer #{credential}")
      end
    end

    context "with OAuth2 authentication" do
      it "adds Bearer token to Authorization header" do
        credential = "oauth-access-token"
        credential_store.set_credentials(session_id, "oauth2", credential)

        agent_card = A2a::Types::AgentCard.new(
          name: "testbot",
          url: "http://example.com",
          default_input_modes: [],
          default_output_modes: [],
          security: [{ "oauth2" => [] }],
          security_schemes: {
            "oauth2" => A2a::Types::SecurityScheme.new(
              root: A2a::Types::OAuth2SecurityScheme.new(
                flows: A2a::Types::OAuthFlows.new(
                  authorization_code: {
                    authorization_url: "https://example.com/auth",
                    token_url: "https://example.com/token",
                    scopes: { "read" => "Read scope" }
                  }
                )
              )
            )
          }
        )

        request_payload = { "method" => "message/send" }
        http_kwargs = { headers: {} }

        _, new_kwargs = interceptor.intercept(
          "message/send",
          request_payload,
          http_kwargs,
          agent_card,
          context
        )

        expect(new_kwargs[:headers]["Authorization"]).to eq("Bearer #{credential}")
      end
    end

    context "with OpenID Connect authentication" do
      it "adds Bearer token to Authorization header" do
        credential = "oidc-id-token"
        credential_store.set_credentials(session_id, "oidc", credential)

        agent_card = A2a::Types::AgentCard.new(
          name: "testbot",
          url: "http://example.com",
          default_input_modes: [],
          default_output_modes: [],
          security: [{ "oidc" => [] }],
          security_schemes: {
            "oidc" => A2a::Types::SecurityScheme.new(
              root: A2a::Types::OpenIdConnectSecurityScheme.new(
                open_id_connect_url: "https://example.com/.well-known/openid-configuration"
              )
            )
          }
        )

        request_payload = { "method" => "message/send" }
        http_kwargs = { headers: {} }

        _, new_kwargs = interceptor.intercept(
          "message/send",
          request_payload,
          http_kwargs,
          agent_card,
          context
        )

        expect(new_kwargs[:headers]["Authorization"]).to eq("Bearer #{credential}")
      end
    end

    context "when credential is not available" do
      it "does not modify headers" do
        agent_card = A2a::Types::AgentCard.new(
          name: "testbot",
          url: "http://example.com",
          default_input_modes: [],
          default_output_modes: [],
          security: [{ "apikey" => [] }],
          security_schemes: {
            "apikey" => A2a::Types::SecurityScheme.new(
              root: A2a::Types::APIKeySecurityScheme.new(
                name: "X-API-Key",
                in_: A2a::Types::In::HEADER
              )
            )
          }
        )

        request_payload = { "method" => "message/send" }
        http_kwargs = { headers: {} }

        _, new_kwargs = interceptor.intercept(
          "message/send",
          request_payload,
          http_kwargs,
          agent_card,
          context
        )

        expect(new_kwargs[:headers]).not_to have_key("X-API-Key")
      end
    end

    context "when scheme is in security but not in security_schemes" do
      it "skips the scheme" do
        credential = "secret-key"
        credential_store.set_credentials(session_id, "missing", credential)

        agent_card = A2a::Types::AgentCard.new(
          name: "testbot",
          url: "http://example.com",
          default_input_modes: [],
          default_output_modes: [],
          security: [{ "missing" => [] }],
          security_schemes: {}
        )

        request_payload = { "method" => "message/send" }
        http_kwargs = { headers: {} }

        _, new_kwargs = interceptor.intercept(
          "message/send",
          request_payload,
          http_kwargs,
          agent_card,
          context
        )

        expect(new_kwargs[:headers]).to be_empty
      end
    end
  end
end
