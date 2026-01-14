# frozen_string_literal: true

require "spec_helper"
require "a2a/client/base_client"
require "a2a/client/transports/jsonrpc"
require "faraday"
require "webmock/rspec"

RSpec.describe A2a::Client::BaseClient do
  let(:agent_card) do
    A2a::Types::AgentCard.new(
      name: "Test Agent",
      url: "https://example.com/api",
      capabilities: A2a::Types::AgentCapabilities.new(streaming: true)
    )
  end
  let(:config) { A2a::Client::Config.new(streaming: true) }
  let(:http_client) { Faraday.new }
  let(:transport) do
    A2a::Client::Transports::JSONRPC.new(
      http_client: http_client,
      agent_card: agent_card
    )
  end
  let(:client) do
    described_class.new(
      card: agent_card,
      config: config,
      transport: transport,
      consumers: [],
      middleware: []
    )
  end

  describe "#initialize" do
    it "initializes with card, config, and transport" do
      expect(client.card).to eq(agent_card)
      expect(client.config).to eq(config)
      expect(client.transport).to eq(transport)
    end
  end

  describe "#send_message" do
    let(:message) do
      A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
    end

    context "with non-streaming" do
      let(:config) { A2a::Client::Config.new(streaming: false) }
      let(:agent_card) do
        A2a::Types::AgentCard.new(
          name: "Test Agent",
          url: "https://example.com/api",
          capabilities: A2a::Types::AgentCapabilities.new(streaming: false)
        )
      end

      it "sends non-streaming message and returns Task" do
        task_response = {
          "jsonrpc" => "2.0",
          "id" => "req-123",
          "result" => {
            "id" => "task-123",
            "contextId" => "ctx-123",
            "kind" => "task",
            "status" => { "state" => "submitted" }
          }
        }

        stub_request(:post, "https://example.com/api")
          .to_return(status: 200, body: task_response.to_json)

        events = client.send_message(request: message).to_a
        expect(events.length).to eq(1)
        expect(events[0]).to be_an(Array)
        expect(events[0][0]).to be_a(A2a::Types::Task)
      end

      it "sends non-streaming message and returns Message" do
        message_response = {
          "jsonrpc" => "2.0",
          "id" => "req-123",
          "result" => {
            "kind" => "message",
            "messageId" => "msg-456",
            "role" => "agent",
            "parts" => [{ "kind" => "text", "text" => "Response" }]
          }
        }

        stub_request(:post, "https://example.com/api")
          .to_return(status: 200, body: message_response.to_json)

        events = client.send_message(request: message).to_a
        expect(events.length).to eq(1)
        expect(events[0]).to be_a(A2a::Types::Message)
      end
    end

    context "with streaming" do
      it "yields streaming events" do
        sse_body = <<~SSE
          data: {"jsonrpc":"2.0","id":"req-123","result":{"kind":"task","id":"task-123","contextId":"ctx-123","status":{"state":"submitted"}}}

          data: {"jsonrpc":"2.0","id":"req-123","result":{"kind":"status-update","taskId":"task-123","contextId":"ctx-123","status":{"state":"working"},"final":false}}
        SSE

        stub_request(:post, "https://example.com/api")
          .with(headers: { "Accept" => "text/event-stream" })
          .to_return(status: 200, body: sse_body, headers: { "Content-Type" => "text/event-stream" })

        events = client.send_message(request: message).to_a
        expect(events.length).to eq(2)
        expect(events[0]).to be_an(Array) # [Task, Update]
        expect(events[0][0]).to be_a(A2a::Types::Task)
        expect(events[1]).to be_an(Array)
        expect(events[1][1]).to be_a(A2a::Types::TaskStatusUpdateEvent)
      end

      it "handles immediate Message response" do
        sse_body = <<~SSE
          data: {"jsonrpc":"2.0","id":"req-123","result":{"kind":"message","messageId":"msg-456","role":"agent","parts":[{"kind":"text","text":"Response"}]}}
        SSE

        stub_request(:post, "https://example.com/api")
          .with(headers: { "Accept" => "text/event-stream" })
          .to_return(status: 200, body: sse_body, headers: { "Content-Type" => "text/event-stream" })

        events = client.send_message(request: message).to_a
        expect(events.length).to eq(1)
        expect(events[0]).to be_a(A2a::Types::Message)
      end
    end

    it "calls consumers with events" do
      called_events = []
      consumer = proc { |event, card| called_events << [event, card] }
      client = described_class.new(
        card: agent_card,
        config: config,
        transport: transport,
        consumers: [consumer],
        middleware: []
      )

      task_response = {
        "jsonrpc" => "2.0",
        "id" => "req-123",
        "result" => {
          "id" => "task-123",
          "contextId" => "ctx-123",
          "kind" => "task",
          "status" => { "state" => "submitted" }
        }
      }

      stub_request(:post, "https://example.com/api")
        .to_return(status: 200, body: task_response.to_json)

      config.streaming = false
      agent_card.capabilities.streaming = false

      client.send_message(request: message).to_a
      expect(called_events.length).to eq(1)
    end
  end

  describe "#get_task" do
    it "delegates to transport" do
      params = A2a::Types::TaskQueryParams.new(id: "task-123")
      task_response = {
        "jsonrpc" => "2.0",
        "id" => "req-123",
        "result" => {
          "id" => "task-123",
          "contextId" => "ctx-123",
          "kind" => "task",
          "status" => { "state" => "completed" }
        }
      }

      stub_request(:post, "https://example.com/api")
        .to_return(status: 200, body: task_response.to_json)

      result = client.get_task(request: params)
      expect(result).to be_a(A2a::Types::Task)
      expect(result.id).to eq("task-123")
    end
  end

  describe "#cancel_task" do
    it "delegates to transport" do
      params = A2a::Types::TaskIdParams.new(id: "task-123")
      task_response = {
        "jsonrpc" => "2.0",
        "id" => "req-123",
        "result" => {
          "id" => "task-123",
          "contextId" => "ctx-123",
          "kind" => "task",
          "status" => { "state" => "canceled" }
        }
      }

      stub_request(:post, "https://example.com/api")
        .to_return(status: 200, body: task_response.to_json)

      result = client.cancel_task(request: params)
      expect(result.status.state).to eq("canceled")
    end
  end

  describe "#resubscribe" do
    it "raises error when streaming not supported" do
      config.streaming = false
      params = A2a::Types::TaskIdParams.new(id: "task-123")

      expect do
        client.resubscribe(request: params).to_a
      end.to raise_error(NotImplementedError, /do not support resubscription/)
    end

    it "yields streaming events when supported" do
      sse_body = <<~SSE
        data: {"jsonrpc":"2.0","id":"req-123","result":{"kind":"status-update","taskId":"task-123","contextId":"ctx-123","status":{"state":"working"},"final":false}}
      SSE

      stub_request(:post, "https://example.com/api")
        .with(headers: { "Accept" => "text/event-stream" })
        .to_return(status: 200, body: sse_body, headers: { "Content-Type" => "text/event-stream" })

      params = A2a::Types::TaskIdParams.new(id: "task-123")
      events = client.resubscribe(request: params).to_a
      expect(events.length).to eq(1)
      expect(events[0]).to be_an(Array)
      expect(events[0][1]).to be_a(A2a::Types::TaskStatusUpdateEvent)
    end
  end

  describe "#get_card" do
    it "delegates to transport and updates internal card" do
      extended_card_response = {
        "jsonrpc" => "2.0",
        "id" => "req-123",
        "result" => {
          "name" => "Test Agent Extended",
          "url" => "https://example.com/api",
          "version" => "1.0.0",
          "description" => "Extended",
          "skills" => [],
          "capabilities" => { "streaming" => true },
          "defaultInputModes" => [],
          "defaultOutputModes" => []
        }
      }

      agent_card.supports_authenticated_extended_card = true
      stub_request(:post, "https://example.com/api")
        .to_return(status: 200, body: extended_card_response.to_json)

      card = client.get_card
      expect(card.name).to eq("Test Agent Extended")
      expect(client.card.name).to eq("Test Agent Extended")
    end
  end

  describe "#close" do
    it "closes the transport" do
      expect(transport).to receive(:close)
      client.close
    end
  end
end
