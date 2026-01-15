# frozen_string_literal: true

require "spec_helper"

# Mock grpc module and classes for testing BEFORE requiring the transport
module GRPC
  module Core
    module StatusCodes
      INTERNAL = 13
      NOT_FOUND = 5
    end
  end

  class BadStatus < StandardError
    attr_reader :code, :details

    def initialize(code, details = nil)
      @code = code
      @details = details
      super("gRPC error: #{details || code}")
    end
  end
end

# Mock proto classes
module A2a
  module Grpc
    module A2aPb2
      class Message
        attr_accessor :message_id, :content, :context_id, :task_id, :role, :metadata, :extensions

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end

      class Task
        attr_accessor :id, :context_id, :status, :artifacts, :history, :metadata

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end

      class SendMessageRequest
        attr_accessor :request, :configuration, :metadata

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end

      class SendMessageResponse
        attr_accessor :task, :msg

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end

      class GetTaskRequest
        attr_accessor :name, :history_length

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end

      class CancelTaskRequest
        attr_accessor :name

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end

      class CreateTaskPushNotificationConfigRequest
        attr_accessor :parent, :config_id, :config

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end

      class GetTaskPushNotificationConfigRequest
        attr_accessor :name

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end

      class TaskPushNotificationConfig
        attr_accessor :name, :push_notification_config

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end

      class TaskSubscriptionRequest
        attr_accessor :name

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end

      class GetAgentCardRequest
        def initialize(attrs = {}); end
      end

      class AgentCard
        attr_accessor :name, :description, :version, :url, :preferred_transport

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end

      class StreamResponse
        attr_accessor :msg, :task, :status_update, :artifact_update

        def initialize(attrs = {})
          attrs.each { |k, v| instance_variable_set(:"@#{k}", v) }
        end
      end
    end

    module A2aServicesPb
      class A2AService
        class Stub
          def initialize(_service, channel:)
            @channel = channel
          end

          attr_reader :channel
        end
      end
    end
  end
end

# Now require the transport (it will use our mocked GRPC module)
# We need to stub the require to prevent the LoadError
allow_const = defined?(Kernel) ? Kernel : Object
allow_const.module_eval do
  alias_method :original_require, :require
  def require(name)
    return true if name == "grpc"

    original_require(name)
  end
end

begin
  require_relative "../../../../lib/a2a/client/transports/grpc"
ensure
  allow_const.module_eval do
    alias_method :require, :original_require
  end
end

RSpec.describe A2a::Client::Transports::Grpc do
  let(:mock_channel) { double("GRPC::Channel") }
  let(:mock_stub) { double("A2AService::Stub") }
  let(:agent_card) do
    A2a::Types::AgentCard.new(
      name: "Test Agent",
      url: "grpc://example.com",
      preferred_transport: A2a::Types::TransportProtocol::GRPC
    )
  end

  before do
    allow(A2a::Grpc::A2aServicesPb::A2AService::Stub).to receive(:new).and_return(mock_stub)
    allow(mock_stub).to receive(:send_message)
    allow(mock_stub).to receive(:get_task)
    allow(mock_stub).to receive(:cancel_task)
    allow(mock_stub).to receive(:get_agent_card)
  end

  describe "#initialize" do
    it "initializes with channel and agent card" do
      transport = described_class.new(
        channel: mock_channel,
        agent_card: agent_card
      )
      expect(transport.channel).to eq(mock_channel)
      expect(transport.agent_card).to eq(agent_card)
    end

    it "initializes with interceptors and extensions" do
      interceptors = [double("Interceptor")]
      extensions = %w[ext1 ext2]
      transport = described_class.new(
        channel: mock_channel,
        agent_card: agent_card,
        interceptors: interceptors,
        extensions: extensions
      )
      expect(transport.interceptors).to eq(interceptors)
      expect(transport.extensions).to eq(extensions)
    end

    it "raises error if proto files not found" do
      allow(A2a::Grpc::A2aServicesPb::A2AService::Stub).to receive(:new).and_raise(NameError)
      expect do
        described_class.new(channel: mock_channel, agent_card: agent_card)
      end.to raise_error(LoadError, /A2A gRPC service stubs not found/)
    end
  end

  describe ".create" do
    let(:config) do
      A2a::Client::Config.new(
        grpc_channel_factory: ->(_url) { mock_channel },
        extensions: ["ext1"]
      )
    end

    it "creates a gRPC transport" do
      transport = described_class.create(
        card: agent_card,
        url: "grpc://example.com",
        config: config,
        interceptors: []
      )
      expect(transport).to be_a(described_class)
      expect(transport.channel).to eq(mock_channel)
    end

    it "raises error if grpc_channel_factory is nil" do
      config.grpc_channel_factory = nil
      expect do
        described_class.create(
          card: agent_card,
          url: "grpc://example.com",
          config: config,
          interceptors: []
        )
      end.to raise_error(ArgumentError, "grpc_channel_factory is required when using gRPC")
    end
  end

  describe "#send_message" do
    let(:transport) do
      described_class.new(
        channel: mock_channel,
        agent_card: agent_card
      )
    end
    let(:message) do
      A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
    end
    let(:params) { A2a::Types::MessageSendParams.new(message: message) }
    let(:task_pb) do
      A2a::Grpc::A2aPb2::Task.new(
        id: "task-123",
        context_id: "ctx-123"
      )
    end
    let(:response_pb) do
      A2a::Grpc::A2aPb2::SendMessageResponse.new(task: task_pb)
    end

    before do
      allow(A2a::Utils::ToProto).to receive(:message_send_request).and_return(double("Request"))
      allow(transport).to receive_messages(get_grpc_metadata: {}, apply_interceptors: {})
      allow(mock_stub).to receive(:send_message).and_return(response_pb)
      allow(A2a::Utils::FromProto).to receive(:task).and_return(
        A2a::Types::Task.new(id: "task-123", context_id: "ctx-123")
      )
    end

    it "sends a message and returns Task" do
      result = transport.send_message(request: params)
      expect(result).to be_a(A2a::Types::Task)
      expect(result.id).to eq("task-123")
    end

    it "sends a message and returns Message when msg field is set" do
      msg_pb = A2a::Grpc::A2aPb2::Message.new(message_id: "msg-456")
      response_pb = A2a::Grpc::A2aPb2::SendMessageResponse.new(msg: msg_pb)
      allow(mock_stub).to receive(:send_message).and_return(response_pb)
      allow(A2a::Utils::FromProto).to receive(:message).and_return(
        A2a::Types::Message.new(message_id: "msg-456")
      )

      result = transport.send_message(request: params)
      expect(result).to be_a(A2a::Types::Message)
      expect(result.message_id).to eq("msg-456")
    end
  end

  describe "#get_task" do
    let(:transport) do
      described_class.new(
        channel: mock_channel,
        agent_card: agent_card
      )
    end
    let(:request) { A2a::Types::TaskQueryParams.new(id: "task-123", history_length: 10) }
    let(:task_pb) do
      A2a::Grpc::A2aPb2::Task.new(
        id: "task-123",
        context_id: "ctx-123"
      )
    end

    before do
      allow(transport).to receive(:get_proto_class).with("GetTaskRequest").and_return(A2a::Grpc::A2aPb2::GetTaskRequest)
      allow(transport).to receive_messages(get_grpc_metadata: {}, apply_interceptors: {})
      allow(mock_stub).to receive(:get_task).and_return(task_pb)
      allow(A2a::Utils::FromProto).to receive(:task).and_return(
        A2a::Types::Task.new(id: "task-123", context_id: "ctx-123")
      )
    end

    it "retrieves a task" do
      result = transport.get_task(request: request)
      expect(result).to be_a(A2a::Types::Task)
      expect(result.id).to eq("task-123")
    end
  end

  describe "#cancel_task" do
    let(:transport) do
      described_class.new(
        channel: mock_channel,
        agent_card: agent_card
      )
    end
    let(:request) { A2a::Types::TaskIdParams.new(id: "task-123") }
    let(:task_pb) do
      A2a::Grpc::A2aPb2::Task.new(
        id: "task-123",
        context_id: "ctx-123"
      )
    end

    before do
      allow(transport).to receive(:get_proto_class).with("CancelTaskRequest").and_return(A2a::Grpc::A2aPb2::CancelTaskRequest)
      allow(transport).to receive_messages(get_grpc_metadata: {}, apply_interceptors: {})
      allow(mock_stub).to receive(:cancel_task).and_return(task_pb)
      allow(A2a::Utils::FromProto).to receive(:task).and_return(
        A2a::Types::Task.new(id: "task-123", context_id: "ctx-123")
      )
    end

    it "cancels a task" do
      result = transport.cancel_task(request: request)
      expect(result).to be_a(A2a::Types::Task)
      expect(result.id).to eq("task-123")
    end
  end

  describe "#get_card" do
    let(:transport) do
      described_class.new(
        channel: mock_channel,
        agent_card: agent_card
      )
    end
    let(:card_pb) do
      A2a::Grpc::A2aPb2::AgentCard.new(
        name: "Test Agent",
        url: "grpc://example.com"
      )
    end

    before do
      allow(transport).to receive(:get_proto_class).with("GetAgentCardRequest").and_return(A2a::Grpc::A2aPb2::GetAgentCardRequest)
      allow(transport).to receive_messages(get_grpc_metadata: {}, apply_interceptors: {})
      allow(mock_stub).to receive(:get_agent_card).and_return(card_pb)
      allow(A2a::Utils::FromProto).to receive(:agent_card).and_return(agent_card)
    end

    it "retrieves agent card when needs_extended_card is true" do
      transport.instance_variable_set(:@needs_extended_card, true)
      result = transport.get_card
      expect(result).to eq(agent_card)
    end

    it "returns cached card when needs_extended_card is false" do
      transport.instance_variable_set(:@needs_extended_card, false)
      result = transport.get_card
      expect(result).to eq(agent_card)
      expect(mock_stub).not_to have_received(:get_agent_card)
    end
  end

  describe "#close" do
    let(:transport) do
      described_class.new(
        channel: mock_channel,
        agent_card: agent_card
      )
    end

    it "closes the channel" do
      allow(mock_channel).to receive(:close)
      transport.close
      expect(mock_channel).to have_received(:close)
    end
  end

  describe "GrpcError" do
    it "creates error with code and details" do
      error = A2a::Client::Transports::GrpcError.new(GRPC::Core::StatusCodes::NOT_FOUND, "Task not found")
      expect(error.code).to eq(GRPC::Core::StatusCodes::NOT_FOUND)
      expect(error.details).to eq("Task not found")
      expect(error.message).to include("gRPC error")
      expect(error.message).to include("Task not found")
    end

    it "creates error with default message when details is nil" do
      error = A2a::Client::Transports::GrpcError.new(GRPC::Core::StatusCodes::INTERNAL)
      expect(error.code).to eq(GRPC::Core::StatusCodes::INTERNAL)
      expect(error.details).to be_nil
      expect(error.message).to include("Unknown error")
    end
  end
end
