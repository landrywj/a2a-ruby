# frozen_string_literal: true

require "spec_helper"
require "a2a/client/transports/rest"
require "faraday"
require "webmock/rspec"

RSpec.describe A2a::Client::Transports::REST do
  let(:http_client) { Faraday.new }
  let(:agent_card) do
    A2a::Types::AgentCard.new(
      name: "Test Agent",
      url: "https://example.com/api",
      preferred_transport: A2a::Types::TransportProtocol::HTTP_JSON
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

    it "removes trailing slash from url" do
      transport = described_class.new(http_client: http_client, url: "https://test.com/")
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
        "id" => "task-123",
        "contextId" => "ctx-123",
        "kind" => "task",
        "status" => {
          "state" => "submitted"
        }
      }
    end

    it "sends a non-streaming message and returns Task" do
      stub_request(:post, "https://example.com/api/v1/message:send")
        .with(
          body: hash_including("request" => anything),
          headers: { "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: task_response.to_json)

      result = transport.send_message(request: params)
      expect(result).to be_a(A2a::Types::Task)
      expect(result.id).to eq("task-123")
    end

    it "sends a non-streaming message and returns Message" do
      message_response = {
        "kind" => "message",
        "messageId" => "msg-456",
        "role" => "agent",
        "parts" => [{ "kind" => "text", "text" => "Response" }]
      }

      stub_request(:post, "https://example.com/api/v1/message:send")
        .to_return(status: 200, body: message_response.to_json)

      result = transport.send_message(request: params)
      expect(result).to be_a(A2a::Types::Message)
      expect(result.message_id).to eq("msg-456")
    end

    it "includes configuration in request payload" do
      config = A2a::Types::MessageSendConfiguration.new(blocking: true)
      params_with_config = A2a::Types::MessageSendParams.new(message: message, configuration: config)

      stub_request(:post, "https://example.com/api/v1/message:send")
        .with(body: hash_including("configuration" => anything))
        .to_return(status: 200, body: task_response.to_json)

      result = transport.send_message(request: params_with_config)
      expect(result).to be_a(A2a::Types::Task)
    end

    it "raises HTTPError on error response" do
      stub_request(:post, "https://example.com/api/v1/message:send")
        .to_return(status: 500, body: "Internal Server Error")

      expect do
        transport.send_message(request: params)
      end.to raise_error(A2a::Client::HTTPError)
    end

    it "raises TimeoutError on timeout" do
      stub_request(:post, "https://example.com/api/v1/message:send")
        .to_timeout

      expect do
        transport.send_message(request: params)
      end.to raise_error(A2a::Client::TimeoutError)
    end

    it "applies interceptors" do
      interceptor = instance_double(A2a::Client::CallInterceptor)
      allow(interceptor).to receive(:intercept).and_return([{}, { headers: { "X-Custom" => "value" } }])
      transport = described_class.new(http_client: http_client, agent_card: agent_card, interceptors: [interceptor])

      stub_request(:post, "https://example.com/api/v1/message:send")
        .with(headers: { "Content-Type" => "application/json", "X-Custom" => "value" })
        .to_return(status: 200, body: task_response.to_json)

      transport.send_message(request: params)
      expect(interceptor).to have_received(:intercept)
    end

    it "includes extension headers" do
      transport = described_class.new(http_client: http_client, agent_card: agent_card, extensions: %w[ext1 ext2])

      stub_request(:post, "https://example.com/api/v1/message:send")
        .with(headers: { "Content-Type" => "application/json", "X-A2A-Extensions" => "ext1,ext2" })
        .to_return(status: 200, body: task_response.to_json)

      result = transport.send_message(request: params)
      expect(result).to be_a(A2a::Types::Task)
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

    it "streams task status updates" do
      sse_body = <<~SSE
        data: {"result": {"kind": "task", "id": "task-123", "contextId": "ctx-123", "status": {"state": "working"}}}

        data: {"result": {"kind": "status-update", "taskId": "task-123", "status": {"state": "completed"}}}
      SSE

      stub_request(:post, "https://example.com/api/v1/message:stream")
        .with(
          body: hash_including("request" => anything),
          headers: { "Accept" => "text/event-stream", "Content-Type" => "application/json" }
        )
        .to_return(status: 200, body: sse_body, headers: { "Content-Type" => "text/event-stream" })

      results = transport.send_message_streaming(request: params).to_a
      expect(results.length).to eq(2)
      expect(results[0]).to be_a(A2a::Types::Task)
      expect(results[1]).to be_a(A2a::Types::TaskStatusUpdateEvent)
    end

    it "handles empty SSE stream" do
      stub_request(:post, "https://example.com/api/v1/message:stream")
        .to_return(status: 200, body: "", headers: { "Content-Type" => "text/event-stream" })

      results = transport.send_message_streaming(request: params).to_a
      expect(results).to be_empty
    end

    it "raises HTTPError on error response" do
      stub_request(:post, "https://example.com/api/v1/message:stream")
        .to_return(status: 500, body: "Internal Server Error")

      expect do
        transport.send_message_streaming(request: params).to_a
      end.to raise_error(A2a::Client::HTTPError)
    end
  end

  describe "#get_task" do
    let(:params) { A2a::Types::TaskQueryParams.new(id: "task-123", history_length: 10) }
    let(:task_response) do
      {
        "id" => "task-123",
        "contextId" => "ctx-123",
        "kind" => "task",
        "status" => { "state" => "completed" }
      }
    end

    it "retrieves a task by id" do
      stub_request(:get, "https://example.com/api/v1/tasks/task-123")
        .with(query: { "historyLength" => "10" })
        .to_return(status: 200, body: task_response.to_json)

      result = transport.get_task(request: params)
      expect(result).to be_a(A2a::Types::Task)
      expect(result.id).to eq("task-123")
    end

    it "omits historyLength query param when not provided" do
      params_no_history = A2a::Types::TaskQueryParams.new(id: "task-123")

      stub_request(:get, "https://example.com/api/v1/tasks/task-123")
        .with(query: {})
        .to_return(status: 200, body: task_response.to_json)

      result = transport.get_task(request: params_no_history)
      expect(result).to be_a(A2a::Types::Task)
    end

    it "raises HTTPError on error response" do
      stub_request(:get, "https://example.com/api/v1/tasks/task-123")
        .with(query: { "historyLength" => "10" })
        .to_return(status: 404, body: "Not Found")

      expect do
        transport.get_task(request: params)
      end.to raise_error(A2a::Client::HTTPError)
    end
  end

  describe "#cancel_task" do
    let(:params) { A2a::Types::TaskIdParams.new(id: "task-123") }
    let(:task_response) do
      {
        "id" => "task-123",
        "contextId" => "ctx-123",
        "kind" => "task",
        "status" => { "state" => "canceled" }
      }
    end

    it "cancels a task" do
      stub_request(:post, "https://example.com/api/v1/tasks/task-123:cancel")
        .with(body: hash_including("name" => "tasks/task-123"))
        .to_return(status: 200, body: task_response.to_json)

      result = transport.cancel_task(request: params)
      expect(result).to be_a(A2a::Types::Task)
      expect(result.id).to eq("task-123")
    end

    it "raises HTTPError on error response" do
      stub_request(:post, "https://example.com/api/v1/tasks/task-123:cancel")
        .to_return(status: 404, body: "Task not found")

      expect do
        transport.cancel_task(request: params)
      end.to raise_error(A2a::Client::HTTPError)
    end
  end

  describe "#set_task_callback" do
    let(:push_config) do
      A2a::Types::PushNotificationConfig.new(
        id: "config-123",
        url: "https://callback.example.com/notify",
        token: "token-123"
      )
    end
    let(:request) do
      A2a::Types::TaskPushNotificationConfig.new(
        task_id: "task-123",
        push_notification_config: push_config
      )
    end
    let(:response_data) do
      {
        "taskId" => "task-123",
        "pushNotificationConfig" => {
          "id" => "config-123",
          "url" => "https://callback.example.com/notify",
          "token" => "token-123"
        }
      }
    end

    it "sets push notification configuration" do
      stub_request(:post, "https://example.com/api/v1/tasks/task-123/pushNotificationConfigs")
        .with(
          body: hash_including(
            "parent" => "tasks/task-123",
            "configId" => "config-123",
            "config" => anything
          )
        )
        .to_return(status: 200, body: response_data.to_json)

      result = transport.set_task_callback(request: request)
      expect(result).to be_a(A2a::Types::TaskPushNotificationConfig)
      expect(result.task_id).to eq("task-123")
      expect(result.push_notification_config.id).to eq("config-123")
    end

    it "raises HTTPError on error response" do
      stub_request(:post, "https://example.com/api/v1/tasks/task-123/pushNotificationConfigs")
        .to_return(status: 400, body: "Bad Request")

      expect do
        transport.set_task_callback(request: request)
      end.to raise_error(A2a::Client::HTTPError)
    end
  end

  describe "#get_task_callback" do
    let(:params) do
      A2a::Types::GetTaskPushNotificationConfigParams.new(
        id: "task-123",
        push_notification_config_id: "config-123"
      )
    end
    let(:response_data) do
      {
        "id" => "config-123",
        "url" => "https://callback.example.com/notify",
        "token" => "token-123"
      }
    end

    it "retrieves push notification configuration" do
      # Response might be just the config or full TaskPushNotificationConfig
      full_response = {
        "taskId" => "task-123",
        "pushNotificationConfig" => response_data
      }

      stub_request(:get, "https://example.com/api/v1/tasks/task-123/pushNotificationConfigs/config-123")
        .to_return(status: 200, body: full_response.to_json)

      result = transport.get_task_callback(request: params)
      expect(result).to be_a(A2a::Types::TaskPushNotificationConfig)
      expect(result.task_id).to eq("task-123")
      expect(result.push_notification_config.id).to eq("config-123")
    end

    it "raises ArgumentError when push_notification_config_id is missing" do
      params_no_id = A2a::Types::GetTaskPushNotificationConfigParams.new(id: "task-123")

      expect do
        transport.get_task_callback(request: params_no_id)
      end.to raise_error(ArgumentError, "push_notification_config_id is required")
    end

    it "raises HTTPError on error response" do
      stub_request(:get, "https://example.com/api/v1/tasks/task-123/pushNotificationConfigs/config-123")
        .to_return(status: 404, body: "Not Found")

      expect do
        transport.get_task_callback(request: params)
      end.to raise_error(A2a::Client::HTTPError)
    end
  end

  describe "#resubscribe" do
    let(:params) { A2a::Types::TaskIdParams.new(id: "task-123") }

    it "streams task updates via SSE" do
      sse_body = <<~SSE
        data: {"result": {"kind": "task", "id": "task-123", "contextId": "ctx-123", "status": {"state": "working"}}}

        data: {"result": {"kind": "artifact-update", "taskId": "task-123", "artifact": {"kind": "text", "text": "Update"}}}
      SSE

      stub_request(:get, "https://example.com/api/v1/tasks/task-123:subscribe")
        .with(headers: { "Accept" => "text/event-stream" })
        .to_return(status: 200, body: sse_body, headers: { "Content-Type" => "text/event-stream" })

      results = transport.resubscribe(request: params).to_a
      expect(results.length).to eq(2)
      expect(results[0]).to be_a(A2a::Types::Task)
      expect(results[1]).to be_a(A2a::Types::TaskArtifactUpdateEvent)
    end

    it "raises HTTPError on error response" do
      stub_request(:get, "https://example.com/api/v1/tasks/task-123:subscribe")
        .to_return(status: 404, body: "Not Found")

      expect do
        transport.resubscribe(request: params).to_a
      end.to raise_error(A2a::Client::HTTPError)
    end
  end

  describe "#get_card" do
    let(:card_response) do
      {
        "name" => "Test Agent",
        "url" => "https://example.com/api",
        "preferredTransport" => "HTTP+JSON",
        "capabilities" => {},
        "defaultInputModes" => [],
        "defaultOutputModes" => [],
        "description" => "",
        "skills" => [],
        "version" => "",
        "supportsAuthenticatedExtendedCard" => false
      }
    end

    context "when agent_card is not set" do
      let(:transport) { described_class.new(http_client: http_client, url: "https://example.com/api") }

      it "fetches agent card from well-known path" do
        stub_request(:get, "https://example.com/api/.well-known/agent-card.json")
          .to_return(status: 200, body: card_response.to_json)

        stub_request(:get, "https://example.com/api/v1/card")
          .to_return(status: 200, body: card_response.to_json)

        result = transport.get_card
        expect(result).to be_a(A2a::Types::AgentCard)
        expect(result.name).to eq("Test Agent")
      end
    end

    context "when agent_card is already set" do
      it "returns existing card if extended card not needed" do
        card = A2a::Types::AgentCard.new(
          name: "Test Agent",
          url: "https://example.com/api",
          supports_authenticated_extended_card: false
        )
        transport = described_class.new(http_client: http_client, agent_card: card)

        result = transport.get_card
        expect(result).to eq(card)
      end

      it "fetches extended card when needed" do
        card = A2a::Types::AgentCard.new(
          name: "Test Agent",
          url: "https://example.com/api",
          supports_authenticated_extended_card: true
        )
        transport = described_class.new(http_client: http_client, agent_card: card)

        stub_request(:get, "https://example.com/api/v1/card")
          .to_return(status: 200, body: card_response.to_json)

        result = transport.get_card
        expect(result).to be_a(A2a::Types::AgentCard)
      end
    end

    it "calls signature_verifier if provided" do
      verifier = instance_double(Proc)
      allow(verifier).to receive(:call)

      card = A2a::Types::AgentCard.new(
        name: "Test Agent",
        url: "https://example.com/api",
        supports_authenticated_extended_card: true
      )
      transport = described_class.new(http_client: http_client, agent_card: card)

      stub_request(:get, "https://example.com/api/v1/card")
        .to_return(status: 200, body: card_response.to_json)

      transport.get_card(signature_verifier: verifier)
      expect(verifier).to have_received(:call)
    end
  end

  describe "#close" do
    it "closes the transport" do
      expect { transport.close }.not_to raise_error
      expect(transport.http_client).to be_nil
    end
  end

  describe "error handling" do
    let(:message) do
      A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
    end
    let(:params) { A2a::Types::MessageSendParams.new(message: message) }

    it "raises JSONError on invalid JSON response" do
      stub_request(:post, "https://example.com/api/v1/message:send")
        .to_return(status: 200, body: "invalid json")

      expect do
        transport.send_message(request: params)
      end.to raise_error(A2a::Client::JSONError)
    end

    it "handles network errors" do
      stub_request(:post, "https://example.com/api/v1/message:send")
        .to_raise(Faraday::ConnectionFailed.new("Connection failed"))

      expect do
        transport.send_message(request: params)
      end.to raise_error(A2a::Client::HTTPError)
    end
  end
end
