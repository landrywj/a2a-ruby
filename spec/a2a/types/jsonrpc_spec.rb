# frozen_string_literal: true

require "spec_helper"
require "a2a/types"

RSpec.describe A2a::Types::JSONRPCRequest do
  describe "#initialize" do
    it "creates a JSON-RPC request with method and params" do
      request = described_class.new(
        id: "req-123",
        method: "test/method",
        params: { "key" => "value" }
      )

      expect(request.id).to eq("req-123")
      expect(request.jsonrpc).to eq("2.0")
      expect(request.method).to eq("test/method")
      expect(request.params).to eq({ "key" => "value" })
    end

    it "defaults jsonrpc to 2.0" do
      request = described_class.new(method: "test/method")
      expect(request.jsonrpc).to eq("2.0")
    end
  end
end

RSpec.describe A2a::Types::SendMessageRequest do
  describe "#initialize" do
    let(:message) do
      A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
    end
    let(:params) { A2a::Types::MessageSendParams.new(message: message) }

    it "creates a send message request" do
      request = described_class.new(id: "req-123", params: params)

      expect(request.id).to eq("req-123")
      expect(request.method).to eq("message/send")
      expect(request.jsonrpc).to eq("2.0")
      expect(request.params).to eq(params)
    end
  end
end

RSpec.describe A2a::Types::SendStreamingMessageRequest do
  describe "#initialize" do
    let(:message) do
      A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
    end
    let(:params) { A2a::Types::MessageSendParams.new(message: message) }

    it "creates a streaming message request" do
      request = described_class.new(id: "req-123", params: params)

      expect(request.method).to eq("message/stream")
      expect(request.params).to eq(params)
    end
  end
end

RSpec.describe A2a::Types::GetTaskRequest do
  describe "#initialize" do
    let(:params) { A2a::Types::TaskQueryParams.new(id: "task-123") }

    it "creates a get task request" do
      request = described_class.new(id: "req-123", params: params)

      expect(request.method).to eq("tasks/get")
      expect(request.params).to eq(params)
    end
  end
end

RSpec.describe A2a::Types::CancelTaskRequest do
  describe "#initialize" do
    let(:params) { A2a::Types::TaskIdParams.new(id: "task-123") }

    it "creates a cancel task request" do
      request = described_class.new(id: "req-123", params: params)

      expect(request.method).to eq("tasks/cancel")
      expect(request.params).to eq(params)
    end
  end
end

RSpec.describe A2a::Types::JSONRPCError do
  describe "#initialize" do
    it "creates a JSON-RPC error" do
      error = described_class.new(
        code: -32_601,
        message: "Method not found",
        data: { "details" => "test" }
      )

      expect(error.code).to eq(-32_601)
      expect(error.message).to eq("Method not found")
      expect(error.data).to eq({ "details" => "test" })
    end
  end
end

RSpec.describe A2a::Types::JSONRPCErrorResponse do
  describe "#initialize" do
    it "creates an error response" do
      error = A2a::Types::JSONRPCError.new(code: -32_601, message: "Error")
      response = described_class.new(id: "req-123", error: error)

      expect(response.id).to eq("req-123")
      expect(response.jsonrpc).to eq("2.0")
      expect(response.error).to eq(error)
    end
  end
end

RSpec.describe A2a::Types::JSONRPCSuccessResponse do
  describe "#initialize" do
    it "creates a success response" do
      response = described_class.new(
        id: "req-123",
        result: { "key" => "value" }
      )

      expect(response.id).to eq("req-123")
      expect(response.jsonrpc).to eq("2.0")
      expect(response.result).to eq({ "key" => "value" })
    end
  end
end
