# frozen_string_literal: true

require "spec_helper"
require "a2a/client/card_resolver"
require "faraday"
require "webmock/rspec"

RSpec.describe A2a::Client::CardResolver do
  let(:base_url) { "https://example.com" }
  let(:http_client) { Faraday.new }
  let(:resolver) { described_class.new(http_client, base_url) }

  let(:valid_agent_card_data) do
    {
      "name" => "Test Agent",
      "description" => "A test agent",
      "version" => "1.0.0",
      "url" => base_url,
      "preferredTransport" => "JSONRPC"
    }
  end

  describe "#initialize" do
    it "sets base_url and agent_card_path" do
      expect(resolver.base_url).to eq(base_url)
      expect(resolver.agent_card_path).to eq(".well-known/agent-card.json")
    end

    it "strips trailing slash from base_url" do
      resolver = described_class.new(http_client, "#{base_url}/")
      expect(resolver.base_url).to eq(base_url)
    end

    it "strips leading slash from agent_card_path" do
      resolver = described_class.new(http_client, base_url, agent_card_path: "/custom/path")
      expect(resolver.agent_card_path).to eq("custom/path")
    end

    it "uses default agent card path" do
      expect(resolver.agent_card_path).to eq(".well-known/agent-card.json")
    end
  end

  describe "#get_agent_card" do
    context "with successful response" do
      it "fetches agent card from default path" do
        stub_request(:get, "#{base_url}/.well-known/agent-card.json")
          .to_return(status: 200, body: valid_agent_card_data.to_json, headers: { "Content-Type" => "application/json" })

        card = resolver.get_agent_card

        expect(card).to be_a(A2a::Types::AgentCard)
        expect(card.name).to eq("Test Agent")
        expect(card.url).to eq(base_url)
      end

      it "fetches agent card from custom path" do
        custom_path = "custom/path/card"
        stub_request(:get, "#{base_url}/#{custom_path}")
          .to_return(status: 200, body: valid_agent_card_data.to_json, headers: { "Content-Type" => "application/json" })

        card = resolver.get_agent_card(relative_card_path: custom_path)

        expect(card).to be_a(A2a::Types::AgentCard)
      end

      it "strips leading slash from relative_card_path" do
        custom_path = "/custom/path"
        stub_request(:get, "#{base_url}/custom/path")
          .to_return(status: 200, body: valid_agent_card_data.to_json, headers: { "Content-Type" => "application/json" })

        card = resolver.get_agent_card(relative_card_path: custom_path)
        expect(card).to be_a(A2a::Types::AgentCard)
      end

      it "calls signature_verifier if provided" do
        stub_request(:get, "#{base_url}/.well-known/agent-card.json")
          .to_return(status: 200, body: valid_agent_card_data.to_json, headers: { "Content-Type" => "application/json" })

        verified = false
        verifier = proc { |_card| verified = true }

        resolver.get_agent_card(signature_verifier: verifier)

        expect(verified).to be(true)
      end

      it "passes http_kwargs to the request" do
        stub_request(:get, "#{base_url}/.well-known/agent-card.json")
          .with(headers: { "Authorization" => "Bearer token" })
          .to_return(status: 200, body: valid_agent_card_data.to_json, headers: { "Content-Type" => "application/json" })

        card = resolver.get_agent_card(http_kwargs: { headers: { "Authorization" => "Bearer token" } })
        expect(card).to be_a(A2a::Types::AgentCard)
      end
    end

    context "with HTTP errors" do
      it "raises HTTPError for non-2xx status codes" do
        stub_request(:get, "#{base_url}/.well-known/agent-card.json")
          .to_return(status: 404, body: "Not Found")

        expect { resolver.get_agent_card }.to raise_error(A2a::Client::HTTPError) do |error|
          expect(error.status_code).to eq(404)
        end
      end

      it "raises HTTPError for network errors" do
        stub_request(:get, "#{base_url}/.well-known/agent-card.json")
          .to_raise(Faraday::ConnectionFailed.new("Connection failed"))

        expect do
          resolver.get_agent_card
        end.to raise_error(A2a::Client::HTTPError, /Network communication error/)
      end
    end

    context "with JSON errors" do
      it "raises JSONError for invalid JSON" do
        stub_request(:get, "#{base_url}/.well-known/agent-card.json")
          .to_return(status: 200, body: "invalid json")

        expect do
          resolver.get_agent_card
        end.to raise_error(A2a::Client::JSONError, /Failed to parse JSON/)
      end
    end
  end
end
