# frozen_string_literal: true

require "spec_helper"
require "a2a/types"

RSpec.describe A2a::Types::TaskQueryParams do
  describe "#initialize" do
    it "creates params with id" do
      params = described_class.new(id: "task-123")
      expect(params.id).to eq("task-123")
    end

    it "accepts history_length" do
      params = described_class.new(id: "task-123", history_length: 10)
      expect(params.history_length).to eq(10)
    end

    it "accepts metadata" do
      params = described_class.new(id: "task-123", metadata: { "key" => "value" })
      expect(params.metadata).to eq({ "key" => "value" })
    end

    it "handles camelCase keys" do
      params = described_class.new("id" => "task-123", "historyLength" => 5)
      expect(params.id).to eq("task-123")
      expect(params.history_length).to eq(5)
    end
  end
end

RSpec.describe A2a::Types::TaskIdParams do
  describe "#initialize" do
    it "creates params with id" do
      params = described_class.new(id: "task-123")
      expect(params.id).to eq("task-123")
    end

    it "accepts metadata" do
      params = described_class.new(id: "task-123", metadata: { "key" => "value" })
      expect(params.metadata).to eq({ "key" => "value" })
    end
  end
end

RSpec.describe A2a::Types::MessageSendParams do
  describe "#initialize" do
    let(:message) do
      A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
    end

    it "creates params with message" do
      params = described_class.new(message: message)
      expect(params.message).to eq(message)
    end

    it "accepts configuration" do
      config = A2a::Types::MessageSendConfiguration.new(blocking: true)
      params = described_class.new(message: message, configuration: config)
      expect(params.configuration).to eq(config)
    end

    it "accepts metadata" do
      params = described_class.new(message: message, metadata: { "key" => "value" })
      expect(params.metadata).to eq({ "key" => "value" })
    end

    it "handles hash input for message" do
      params = described_class.new(
        message: {
          "role" => "user",
          "messageId" => "msg-123",
          "parts" => [{ "kind" => "text", "text" => "Hello" }]
        }
      )
      expect(params.message).to be_a(A2a::Types::Message)
    end
  end
end

RSpec.describe A2a::Types::MessageSendConfiguration do
  describe "#initialize" do
    it "creates configuration with defaults" do
      config = described_class.new
      expect(config.accepted_output_modes).to eq([])
      expect(config.blocking).to be true
    end

    it "accepts accepted_output_modes" do
      config = described_class.new(accepted_output_modes: ["text/plain"])
      expect(config.accepted_output_modes).to eq(["text/plain"])
    end

    it "accepts blocking flag" do
      config = described_class.new(blocking: false)
      expect(config.blocking).to be false
    end

    it "accepts push_notification_config" do
      push_config = A2a::Types::PushNotificationConfig.new(
        url: "https://callback.com",
        token: "token-123"
      )
      config = described_class.new(push_notification_config: push_config)
      expect(config.push_notification_config).to eq(push_config)
    end
  end
end

RSpec.describe A2a::Types::TaskPushNotificationConfig do
  describe "#initialize" do
    let(:push_config) do
      A2a::Types::PushNotificationConfig.new(
        url: "https://callback.com",
        token: "token-123"
      )
    end

    it "creates config with task_id and push_notification_config" do
      config = described_class.new(
        task_id: "task-123",
        push_notification_config: push_config
      )

      expect(config.task_id).to eq("task-123")
      expect(config.push_notification_config).to eq(push_config)
    end

    it "handles camelCase keys" do
      config = described_class.new(
        "taskId" => "task-123",
        "pushNotificationConfig" => {
          "url" => "https://callback.com",
          "token" => "token-123"
        }
      )

      expect(config.task_id).to eq("task-123")
      expect(config.push_notification_config).to be_a(A2a::Types::PushNotificationConfig)
    end
  end
end

RSpec.describe A2a::Types::PushNotificationConfig do
  describe "#initialize" do
    it "creates config with url and token" do
      config = described_class.new(
        url: "https://callback.com",
        token: "token-123"
      )

      expect(config.url).to eq("https://callback.com")
      expect(config.token).to eq("token-123")
    end

    it "accepts authentication" do
      auth = A2a::Types::PushNotificationAuthenticationInfo.new(
        schemes: ["Bearer"],
        credentials: "cred-123"
      )
      config = described_class.new(
        url: "https://callback.com",
        token: "token-123",
        authentication: auth
      )

      expect(config.authentication).to eq(auth)
    end
  end
end

RSpec.describe A2a::Types::PushNotificationAuthenticationInfo do
  describe "#initialize" do
    it "creates auth info with schemes" do
      auth = described_class.new(schemes: ["Bearer", "Basic"])
      expect(auth.schemes).to eq(["Bearer", "Basic"])
    end

    it "accepts credentials" do
      auth = described_class.new(
        schemes: ["Bearer"],
        credentials: "cred-123"
      )
      expect(auth.credentials).to eq("cred-123")
    end

    it "defaults schemes to empty array" do
      auth = described_class.new
      expect(auth.schemes).to eq([])
    end
  end
end

RSpec.describe A2a::Types::GetTaskPushNotificationConfigParams do
  describe "#initialize" do
    it "creates params with id" do
      params = described_class.new(id: "task-123")
      expect(params.id).to eq("task-123")
    end

    it "accepts metadata" do
      params = described_class.new(id: "task-123", metadata: { "key" => "value" })
      expect(params.metadata).to eq({ "key" => "value" })
    end
  end
end
