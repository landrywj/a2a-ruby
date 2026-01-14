# frozen_string_literal: true

require "spec_helper"
require "a2a/client/transports/jsonrpc"
require "faraday"
require "webmock/rspec"

RSpec.describe A2a::Client::Transports::JSONRPC do
  let(:http_client) { Faraday.new }
  let(:agent_card) do
    A2a::Types::AgentCard.new(
      name: "Test Agent",
      url: "https://example.com/api",
      preferred_transport: A2a::Types::TransportProtocol::JSONRPC
    )
  end
  let(:transport) { described_class.new(http_client: http_client, agent_card: agent_card) }

  describe "#initialize" do
    it "initializes with agent card" do
      expect(transport.url).to eq("https://example.com/api")
      expect(transport.agent_card).to eq(agent_card)
    end

    it "initializes with url" do
      transport = described_class.new(http_client: http_client, url: "https://test.com")
      expect(transport.url).to eq("https://test.com")
    end

    it "raises error if neither agent_card nor url provided" do
      expect do
        described_class.new(http_client: http_client)
      end.to raise_error(ArgumentError, "Must provide either agent_card or url")
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
    let(:params) { A2a::Types::MessageSendParams.new(message: message) }
    let(:task_response) do
      {
        "jsonrpc" => "2.0",
        "id" => "req-123",
        "result" => {
          "id" => "task-123",
          "contextId" => "ctx-123",
          "kind" => "task",
          "status" => {
            "state" => "submitted"
          }
        }
      }
    end

    it "sends a non-streaming message and returns Task" do
      stub_request(:post, "https://example.com/api")
        .with(
          body: hash_including("method" => "message/send", "params" => anything),
          headers: { "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: task_response.to_json)

      result = transport.send_message(request: params)
      expect(result).to be_a(A2a::Types::Task)
      expect(result.id).to eq("task-123")
    end

    it "sends a non-streaming message and returns Message" do
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

      result = transport.send_message(request: params)
      expect(result).to be_a(A2a::Types::Message)
      expect(result.message_id).to eq("msg-456")
    end

    it "raises JSONRPCError on error response" do
      error_response = {
        "jsonrpc" => "2.0",
        "id" => "req-123",
        "error" => {
          "code" => -32_601,
          "message" => "Method not found"
        }
      }

      stub_request(:post, "https://example.com/api")
        .to_return(status: 200, body: error_response.to_json)

      expect do
        transport.send_message(request: params)
      end.to raise_error(A2a::Client::JSONRPCError)
    end

    it "raises HTTPError on HTTP error" do
      stub_request(:post, "https://example.com/api")
        .to_return(status: 500, body: "Internal Server Error")

      expect do
        transport.send_message(request: params)
      end.to raise_error(A2a::Client::HTTPError) do |error|
        expect(error.status_code).to eq(500)
      end
    end

    it "raises TimeoutError on timeout" do
      stub_request(:post, "https://example.com/api")
        .to_timeout

      expect do
        transport.send_message(request: params)
      end.to raise_error(A2a::Client::TimeoutError)
    end

    it "applies interceptors" do
      interceptor = double("interceptor")
      allow(interceptor).to receive(:intercept).and_return([{ "method" => "message/send" }, {}])
      transport = described_class.new(
        http_client: http_client,
        agent_card: agent_card,
        interceptors: [interceptor]
      )

      stub_request(:post, "https://example.com/api")
        .to_return(status: 200, body: task_response.to_json)

      transport.send_message(request: params)
      expect(interceptor).to have_received(:intercept)
    end
  end

  describe "#send_message_streaming" do
    let(:message) do
      A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
    end
    let(:params) { A2a::Types::MessageSendParams.new(message: message) }

    it "yields streaming events from SSE" do
      sse_body = <<~SSE
        data: {"jsonrpc":"2.0","id":"req-123","result":{"kind":"task","id":"task-123","contextId":"ctx-123","status":{"state":"submitted"}}}

        data: {"jsonrpc":"2.0","id":"req-123","result":{"kind":"status-update","taskId":"task-123","contextId":"ctx-123","status":{"state":"working"},"final":false}}

        data: {"jsonrpc":"2.0","id":"req-123","result":{"kind":"status-update","taskId":"task-123","contextId":"ctx-123","status":{"state":"completed"},"final":true}}
      SSE

      stub_request(:post, "https://example.com/api")
        .with(headers: { "Accept" => "text/event-stream" })
        .to_return(status: 200, body: sse_body, headers: { "Content-Type" => "text/event-stream" })

      events = transport.send_message_streaming(request: params).to_a
      expect(events.length).to eq(3)
      expect(events[0]).to be_a(A2a::Types::Task)
      expect(events[1]).to be_a(A2a::Types::TaskStatusUpdateEvent)
      expect(events[2]).to be_a(A2a::Types::TaskStatusUpdateEvent)
    end

    it "handles empty SSE stream" do
      stub_request(:post, "https://example.com/api")
        .to_return(status: 200, body: "", headers: { "Content-Type" => "text/event-stream" })

      events = transport.send_message_streaming(request: params).to_a
      expect(events).to be_empty
    end
  end

  describe "#get_task" do
    let(:params) { A2a::Types::TaskQueryParams.new(id: "task-123") }
    let(:task_response) do
      {
        "jsonrpc" => "2.0",
        "id" => "req-123",
        "result" => {
          "id" => "task-123",
          "contextId" => "ctx-123",
          "kind" => "task",
          "status" => { "state" => "completed" }
        }
      }
    end

    it "retrieves a task" do
      stub_request(:post, "https://example.com/api")
        .with(
          body: hash_including("method" => "tasks/get", "params" => hash_including("id" => "task-123"))
        )
        .to_return(status: 200, body: task_response.to_json)

      result = transport.get_task(request: params)
      expect(result).to be_a(A2a::Types::Task)
      expect(result.id).to eq("task-123")
    end
  end

  describe "#cancel_task" do
    let(:params) { A2a::Types::TaskIdParams.new(id: "task-123") }
    let(:task_response) do
      {
        "jsonrpc" => "2.0",
        "id" => "req-123",
        "result" => {
          "id" => "task-123",
          "contextId" => "ctx-123",
          "kind" => "task",
          "status" => { "state" => "canceled" }
        }
      }
    end

    it "cancels a task" do
      stub_request(:post, "https://example.com/api")
        .with(
          body: hash_including("method" => "tasks/cancel", "params" => hash_including("id" => "task-123"))
        )
        .to_return(status: 200, body: task_response.to_json)

      result = transport.cancel_task(request: params)
      expect(result).to be_a(A2a::Types::Task)
      expect(result.status.state).to eq("canceled")
    end
  end

  describe "#set_task_callback" do
    let(:push_config) do
      A2a::Types::PushNotificationConfig.new(
        url: "https://callback.com",
        token: "token-123"
      )
    end
    let(:params) do
      A2a::Types::TaskPushNotificationConfig.new(
        task_id: "task-123",
        push_notification_config: push_config
      )
    end
    let(:response_data) do
      {
        "jsonrpc" => "2.0",
        "id" => "req-123",
        "result" => {
          "taskId" => "task-123",
          "pushNotificationConfig" => {
            "url" => "https://callback.com",
            "token" => "token-123"
          }
        }
      }
    end

    it "sets push notification config" do
      stub_request(:post, "https://example.com/api")
        .with(
          body: hash_including("method" => "tasks/pushNotificationConfig/set")
        )
        .to_return(status: 200, body: response_data.to_json)

      result = transport.set_task_callback(request: params)
      expect(result).to be_a(A2a::Types::TaskPushNotificationConfig)
      expect(result.task_id).to eq("task-123")
    end
  end

  describe "#get_task_callback" do
    let(:params) { A2a::Types::GetTaskPushNotificationConfigParams.new(id: "task-123") }
    let(:response_data) do
      {
        "jsonrpc" => "2.0",
        "id" => "req-123",
        "result" => {
          "taskId" => "task-123",
          "pushNotificationConfig" => {
            "url" => "https://callback.com",
            "token" => "token-123"
          }
        }
      }
    end

    it "gets push notification config" do
      stub_request(:post, "https://example.com/api")
        .with(
          body: hash_including("method" => "tasks/pushNotificationConfig/get")
        )
        .to_return(status: 200, body: response_data.to_json)

      result = transport.get_task_callback(request: params)
      expect(result).to be_a(A2a::Types::TaskPushNotificationConfig)
    end
  end

  describe "#resubscribe" do
    let(:params) { A2a::Types::TaskIdParams.new(id: "task-123") }

    it "yields streaming events" do
      sse_body = <<~SSE
        data: {"jsonrpc":"2.0","id":"req-123","result":{"kind":"status-update","taskId":"task-123","contextId":"ctx-123","status":{"state":"working"},"final":false}}
      SSE

      stub_request(:post, "https://example.com/api")
        .with(headers: { "Accept" => "text/event-stream" })
        .to_return(status: 200, body: sse_body, headers: { "Content-Type" => "text/event-stream" })

      events = transport.resubscribe(request: params).to_a
      expect(events.length).to eq(1)
      expect(events[0]).to be_a(A2a::Types::TaskStatusUpdateEvent)
    end
  end

  describe "#get_card" do
    context "when agent_card is already set" do
      it "returns the existing card" do
        # Set needs_extended_card to false so it doesn't try to fetch
        transport.instance_variable_set(:@needs_extended_card, false)
        card = transport.get_card
        expect(card).to eq(agent_card)
      end

      context "when extended card is needed" do
        let(:agent_card) do
          A2a::Types::AgentCard.new(
            name: "Test Agent",
            url: "https://example.com/api",
            supports_authenticated_extended_card: true
          )
        end
        let(:extended_card_response) do
          {
            "jsonrpc" => "2.0",
            "id" => "req-123",
            "result" => {
              "name" => "Test Agent Extended",
              "url" => "https://example.com/api",
              "version" => "1.0.0",
              "description" => "Extended card",
              "skills" => [],
              "capabilities" => {},
              "defaultInputModes" => [],
              "defaultOutputModes" => []
            }
          }
        end

        it "fetches extended card" do
          stub_request(:post, "https://example.com/api")
            .with(
              body: hash_including("method" => "agent/getAuthenticatedExtendedCard")
            )
            .to_return(status: 200, body: extended_card_response.to_json)

          card = transport.get_card
          expect(card.name).to eq("Test Agent Extended")
        end
      end
    end

    context "when agent_card is not set" do
      let(:transport) { described_class.new(http_client: http_client, url: "https://example.com/api") }
      let(:card_response) do
        {
          "name" => "Test Agent",
          "url" => "https://example.com/api",
          "version" => "1.0.0",
          "description" => "Test agent",
          "skills" => [],
          "capabilities" => {},
          "defaultInputModes" => [],
          "defaultOutputModes" => []
        }
      end

      it "fetches card from well-known path" do
        stub_request(:get, "https://example.com/api/.well-known/agent-card.json")
          .to_return(status: 200, body: card_response.to_json)

        card = transport.get_card
        expect(card).to be_a(A2a::Types::AgentCard)
        expect(card.name).to eq("Test Agent")
      end
    end
  end

  describe "#close" do
    it "closes the transport" do
      expect { transport.close }.not_to raise_error
      expect(transport.http_client).to be_nil
    end
  end
end
