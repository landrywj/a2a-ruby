# frozen_string_literal: true

require "spec_helper"
require "a2a/types"

RSpec.describe A2a::Types::TaskStatus do
  describe "#initialize" do
    it "creates a task status with state" do
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
      expect(status.state).to eq("submitted")
    end

    it "creates a task status with message" do
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::AGENT,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Processing"))]
      )
      status = A2a::Types::TaskStatus.new(
        state: A2a::Types::TaskState::WORKING,
        message: message
      )
      expect(status.state).to eq("working")
      expect(status.message).to eq(message)
      expect(status.message.parts.first.root.text).to eq("Processing")
    end

    it "creates a task status with timestamp" do
      timestamp = "2023-10-27T10:00:00Z"
      status = A2a::Types::TaskStatus.new(
        state: A2a::Types::TaskState::COMPLETED,
        timestamp: timestamp
      )
      expect(status.state).to eq("completed")
      expect(status.timestamp).to eq(timestamp)
    end

    it "handles message from hash" do
      status = A2a::Types::TaskStatus.new(
        state: A2a::Types::TaskState::WORKING,
        message: {
          "role" => "agent",
          "messageId" => "msg-123",
          "parts" => [{ "kind" => "text", "text" => "Processing" }]
        }
      )
      expect(status.message).to be_a(A2a::Types::Message)
      expect(status.message.parts.first.root.text).to eq("Processing")
    end

    it "handles camelCase keys" do
      status = A2a::Types::TaskStatus.new("state" => "completed", "timestamp" => "2023-10-27T10:00:00Z")
      expect(status.state).to eq("completed")
      expect(status.timestamp).to eq("2023-10-27T10:00:00Z")
    end
  end

  describe "#to_h" do
    it "serializes to hash" do
      status = A2a::Types::TaskStatus.new(
        state: A2a::Types::TaskState::COMPLETED,
        timestamp: "2023-10-27T10:00:00Z"
      )
      hash = status.to_h
      expect(hash["state"]).to eq("completed")
      expect(hash["timestamp"]).to eq("2023-10-27T10:00:00Z")
    end
  end
end

RSpec.describe A2a::Types::Task do
  describe "#initialize" do
    it "creates a task with all attributes" do
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
      artifact = A2a::Types::Artifact.new(
        artifact_id: "art-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Result"))]
      )

      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        history: [message],
        artifacts: [artifact],
        metadata: { "key" => "value" }
      )

      expect(task.id).to eq("task-123")
      expect(task.context_id).to eq("ctx-123")
      expect(task.kind).to eq("task")
      expect(task.status.state).to eq("submitted")
      expect(task.history.length).to eq(1)
      expect(task.artifacts.length).to eq(1)
      expect(task.metadata).to eq({ "key" => "value" })
    end

    it "creates a task with minimal attributes" do
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status
      )

      expect(task.id).to eq("task-123")
      expect(task.context_id).to eq("ctx-123")
      expect(task.history).to be_nil
      expect(task.artifacts).to be_nil
    end

    it "handles TaskStatus object directly" do
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::COMPLETED)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status
      )
      expect(task.status).to eq(status)
      expect(task.status.state).to eq("completed")
    end

    it "handles TaskStatus from hash" do
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: { "state" => "completed" }
      )
      expect(task.status).to be_a(A2a::Types::TaskStatus)
      expect(task.status.state).to eq("completed")
    end

    it "handles Message objects in history" do
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        history: [message]
      )
      expect(task.history.first).to eq(message)
    end

    it "creates Message objects from hashes in history" do
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        history: [{
          "role" => "user",
          "messageId" => "msg-123",
          "parts" => [{ "kind" => "text", "text" => "Hello" }]
        }]
      )
      expect(task.history.first).to be_a(A2a::Types::Message)
      expect(task.history.first.role).to eq("user")
    end

    it "handles multiple messages in history" do
      msg1 = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-1",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
      msg2 = A2a::Types::Message.new(
        role: A2a::Types::Role::AGENT,
        message_id: "msg-2",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hi"))]
      )
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::WORKING)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        history: [msg1, msg2]
      )
      expect(task.history.length).to eq(2)
      expect(task.history.first.role).to eq("user")
      expect(task.history.last.role).to eq("agent")
    end

    it "handles Artifact objects" do
      artifact = A2a::Types::Artifact.new(
        artifact_id: "art-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Result"))]
      )
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::COMPLETED)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        artifacts: [artifact]
      )
      expect(task.artifacts.first).to eq(artifact)
      expect(task.artifacts.first.artifact_id).to eq("art-123")
    end

    it "creates Artifact objects from hashes" do
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::COMPLETED)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        artifacts: [{
          "artifactId" => "art-123",
          "parts" => [{ "kind" => "text", "text" => "Result" }]
        }]
      )
      expect(task.artifacts.first).to be_a(A2a::Types::Artifact)
      expect(task.artifacts.first.artifact_id).to eq("art-123")
    end

    it "handles camelCase keys" do
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
      task = A2a::Types::Task.new(
        "id" => "task-123",
        "contextId" => "ctx-123",
        "status" => status
      )
      expect(task.id).to eq("task-123")
      expect(task.context_id).to eq("ctx-123")
    end
  end

  describe "#to_h" do
    it "serializes task to hash" do
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::COMPLETED)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status
      )
      hash = task.to_h

      expect(hash["id"]).to eq("task-123")
      expect(hash["contextId"]).to eq("ctx-123")
      expect(hash["kind"]).to eq("task")
      expect(hash["status"]).to be_a(Hash)
      expect(hash["status"]["state"]).to eq("completed")
    end

    it "includes history in serialization" do
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        history: [message]
      )
      hash = task.to_h
      expect(hash["history"]).to be_an(Array)
      expect(hash["history"].first["kind"]).to eq("message")
    end
  end

  describe "#to_json" do
    it "serializes task to JSON" do
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::COMPLETED)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status
      )
      json = task.to_json
      parsed = JSON.parse(json)

      expect(parsed["id"]).to eq("task-123")
      expect(parsed["contextId"]).to eq("ctx-123")
      expect(parsed["kind"]).to eq("task")
    end
  end
end
