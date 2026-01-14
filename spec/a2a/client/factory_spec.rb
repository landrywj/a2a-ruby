# frozen_string_literal: true

require "spec_helper"
require "a2a/client/factory"
require "a2a/client/config"
require "webmock/rspec"

RSpec.describe A2a::Client::Factory do
  let(:config) { A2a::Client::Config.new }
  let(:factory) { described_class.new(config) }

  let(:base_agent_card) do
    A2a::Types::AgentCard.new(
      name: "Test Agent",
      url: "https://example.com",
      preferred_transport: A2a::Types::TransportProtocol::JSONRPC
    )
  end

  describe "#initialize" do
    it "creates factory with config and consumers" do
      consumers = [proc { |_e, _c| }]
      factory = described_class.new(config, consumers: consumers)
      expect(factory.config).to eq(config)
      expect(factory.consumers).to eq(consumers)
    end

    it "registers default transports" do
      expect(factory.registry).to have_key(A2a::Types::TransportProtocol::JSONRPC)
    end
  end

  describe "#register" do
    it "registers a transport producer" do
      producer = proc { |_card, _url, _config, _interceptors| "transport" }
      factory.register("custom", producer)
      expect(factory.registry["custom"]).to eq(producer)
    end
  end

  describe "#create" do
    it "creates a BaseClient with JSON-RPC transport" do
      stub_request(:post, "https://example.com")
        .to_return(status: 200, body: { jsonrpc: "2.0", id: "1", result: {} }.to_json)

      client = factory.create(card: base_agent_card)
      expect(client).to be_a(A2a::Client::BaseClient)
      expect(client.transport).to be_a(A2a::Client::Transports::JSONRPC)
    end

    context "with transport selection" do
      it "selects server preferred transport when use_client_preference is false" do
        config.use_client_preference = false
        card = A2a::Types::AgentCard.new(
          url: "https://example.com",
          preferred_transport: A2a::Types::TransportProtocol::HTTP_JSON,
          additional_interfaces: [
            A2a::Types::AgentInterface.new(
              transport: A2a::Types::TransportProtocol::JSONRPC,
              url: "https://example.com/jsonrpc"
            )
          ]
        )
        config.supported_transports = [A2a::Types::TransportProtocol::HTTP_JSON, A2a::Types::TransportProtocol::JSONRPC]

        # Server prefers HTTP_JSON, but it's not implemented yet (Phase 5)
        expect do
          factory.create(card: card)
        end.to raise_error(NotImplementedError, /REST transport not yet implemented/)
      end

      it "selects client preferred transport when use_client_preference is true" do
        config.use_client_preference = true
        card = A2a::Types::AgentCard.new(
          url: "https://example.com",
          preferred_transport: A2a::Types::TransportProtocol::HTTP_JSON,
          additional_interfaces: [
            A2a::Types::AgentInterface.new(
              transport: A2a::Types::TransportProtocol::JSONRPC,
              url: "https://example.com/jsonrpc"
            )
          ]
        )
        config.supported_transports = [A2a::Types::TransportProtocol::JSONRPC, A2a::Types::TransportProtocol::HTTP_JSON]

        stub_request(:post, "https://example.com/jsonrpc")
          .to_return(status: 200, body: { jsonrpc: "2.0", id: "1", result: {} }.to_json)

        client = factory.create(card: card)
        expect(client).to be_a(A2a::Client::BaseClient)
        expect(client.transport.url).to eq("https://example.com/jsonrpc")
      end

      it "raises ArgumentError when no compatible transports found" do
        card = A2a::Types::AgentCard.new(
          url: "https://example.com",
          preferred_transport: A2a::Types::TransportProtocol::GRPC
        )
        config.supported_transports = [A2a::Types::TransportProtocol::JSONRPC]

        expect do
          factory.create(card: card)
        end.to raise_error(ArgumentError, "no compatible transports found")
      end
    end

    it "merges consumers" do
      factory_consumers = [proc { |_e, _c| :factory }]
      factory = described_class.new(config, consumers: factory_consumers)
      additional_consumers = [proc { |_e, _c| :additional }]

      stub_request(:post, "https://example.com")
        .to_return(status: 200, body: { jsonrpc: "2.0", id: "1", result: {} }.to_json)

      client = factory.create(card: base_agent_card, consumers: additional_consumers)
      expect(client.consumers.length).to eq(2)
    end

    it "merges extensions" do
      config.extensions = ["ext1"]
      additional_extensions = ["ext2"]

      stub_request(:post, "https://example.com")
        .to_return(status: 200, body: { jsonrpc: "2.0", id: "1", result: {} }.to_json)

      client = factory.create(card: base_agent_card, extensions: additional_extensions)
      expect(client.transport.extensions).to include("ext1", "ext2")
    end
  end

  describe ".connect" do
    it "creates client from URL" do
      stub_request(:get, "https://example.com/.well-known/agent-card.json")
        .to_return(
          status: 200,
          body: {
            name: "Test Agent",
            url: "https://example.com",
            preferredTransport: "JSONRPC",
            version: "1.0.0",
            description: "Test",
            skills: [],
            capabilities: {},
            defaultInputModes: [],
            defaultOutputModes: []
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "https://example.com")
        .to_return(status: 200, body: { jsonrpc: "2.0", id: "1", result: {} }.to_json)

      client = described_class.connect(agent: "https://example.com")
      expect(client).to be_a(A2a::Client::BaseClient)
    end

    it "creates client from AgentCard" do
      stub_request(:post, "https://example.com")
        .to_return(status: 200, body: { jsonrpc: "2.0", id: "1", result: {} }.to_json)

      client = described_class.connect(agent: base_agent_card)
      expect(client).to be_a(A2a::Client::BaseClient)
    end

    it "passes resolver arguments" do
      stub_request(:get, "https://example.com/custom/path")
        .with(headers: { "Authorization" => "Bearer token" })
        .to_return(
          status: 200,
          body: {
            name: "Test Agent",
            url: "https://example.com",
            preferredTransport: "JSONRPC",
            version: "1.0.0",
            description: "Test",
            skills: [],
            capabilities: {},
            defaultInputModes: [],
            defaultOutputModes: []
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "https://example.com")
        .to_return(status: 200, body: { jsonrpc: "2.0", id: "1", result: {} }.to_json)

      client = described_class.connect(
        agent: "https://example.com",
        relative_card_path: "custom/path",
        resolver_http_kwargs: { headers: { "Authorization" => "Bearer token" } }
      )
      expect(client).to be_a(A2a::Client::BaseClient)
    end
  end

  describe ".minimal_agent_card" do
    it "creates minimal agent card with URL only" do
      card = described_class.minimal_agent_card(url: "https://example.com")
      expect(card).to be_a(A2a::Types::AgentCard)
      expect(card.url).to eq("https://example.com")
      # When no transports are provided, AgentCard defaults to JSONRPC
      expect(card.preferred_transport).to eq(A2a::Types::TransportProtocol::JSONRPC)
      expect(card.additional_interfaces).to eq([])
    end

    it "creates minimal agent card with transports" do
      card = described_class.minimal_agent_card(
        url: "https://example.com",
        transports: [A2a::Types::TransportProtocol::JSONRPC, A2a::Types::TransportProtocol::HTTP_JSON]
      )
      expect(card.preferred_transport).to eq(A2a::Types::TransportProtocol::JSONRPC)
      expect(card.additional_interfaces.length).to eq(1)
      expect(card.additional_interfaces.first.transport).to eq(A2a::Types::TransportProtocol::HTTP_JSON)
    end
  end
end
