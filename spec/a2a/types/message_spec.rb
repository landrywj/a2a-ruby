# frozen_string_literal: true

require "spec_helper"
require "a2a/types"

RSpec.describe A2a::Types::Message do
  describe "#initialize" do
    it "creates a message with all attributes" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      message = described_class.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part],
        task_id: "task-123",
        context_id: "ctx-123",
        reference_task_ids: %w[ref-1 ref-2],
        extensions: ["ext-1"],
        metadata: { "key" => "value" }
      )

      expect(message.kind).to eq("message")
      expect(message.role).to eq("user")
      expect(message.message_id).to eq("msg-123")
      expect(message.parts.length).to eq(1)
      expect(message.task_id).to eq("task-123")
      expect(message.context_id).to eq("ctx-123")
      expect(message.reference_task_ids).to eq(%w[ref-1 ref-2])
      expect(message.extensions).to eq(["ext-1"])
      expect(message.metadata).to eq({ "key" => "value" })
    end

    it "creates a message with minimal attributes" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      message = described_class.new(
        role: A2a::Types::Role::AGENT,
        message_id: "msg-123",
        parts: [part]
      )

      expect(message.role).to eq("agent")
      expect(message.message_id).to eq("msg-123")
      expect(message.task_id).to be_nil
      expect(message.context_id).to be_nil
    end

    it "handles camelCase keys from JSON" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      message = described_class.new(
        "role" => "user",
        "messageId" => "msg-123",
        "parts" => [part],
        "taskId" => "task-123",
        "contextId" => "ctx-123"
      )

      expect(message.role).to eq("user")
      expect(message.message_id).to eq("msg-123")
      expect(message.task_id).to eq("task-123")
      expect(message.context_id).to eq("ctx-123")
    end

    it "handles Part objects directly" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      message = described_class.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part]
      )
      expect(message.parts.first).to eq(part)
    end

    it "creates Part objects from hashes" do
      message = described_class.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [{ root: { kind: "text", text: "Hello" } }]
      )
      expect(message.parts.first).to be_a(A2a::Types::Part)
      expect(message.parts.first.root.text).to eq("Hello")
    end

    it "handles multiple parts" do
      part1 = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))
      part2 = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "World"))
      message = described_class.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part1, part2]
      )
      expect(message.parts.length).to eq(2)
      expect(message.parts.first.root.text).to eq("Hello")
      expect(message.parts.last.root.text).to eq("World")
    end
  end

  describe "#to_h" do
    it "serializes message to hash with camelCase keys" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      message = described_class.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part],
        task_id: "task-123",
        context_id: "ctx-123"
      )
      hash = message.to_h

      expect(hash["kind"]).to eq("message")
      expect(hash["role"]).to eq("user")
      expect(hash["messageId"]).to eq("msg-123")
      expect(hash["taskId"]).to eq("task-123")
      expect(hash["contextId"]).to eq("ctx-123")
      expect(hash["parts"]).to be_an(Array)
      expect(hash["parts"].first["kind"]).to eq("text")
    end
  end

  describe "#to_json" do
    it "serializes message to JSON" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      message = described_class.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part]
      )
      json = message.to_json
      parsed = JSON.parse(json)

      expect(parsed["kind"]).to eq("message")
      expect(parsed["role"]).to eq("user")
      expect(parsed["messageId"]).to eq("msg-123")
    end
  end

  describe ".from_h" do
    it "creates message from hash" do
      hash = {
        "role" => "user",
        "messageId" => "msg-123",
        "parts" => [{ "kind" => "text", "text" => "Hello" }]
      }
      message = described_class.from_h(hash)
      expect(message.role).to eq("user")
      expect(message.message_id).to eq("msg-123")
      expect(message.parts.length).to eq(1)
    end
  end

  describe ".from_json" do
    it "creates message from JSON string" do
      json = '{"kind":"message","role":"user","messageId":"msg-123","parts":[{"kind":"text","text":"Hello"}]}'
      message = described_class.from_json(json)
      expect(message.role).to eq("user")
      expect(message.message_id).to eq("msg-123")
      expect(message.parts.first.root.text).to eq("Hello")
    end
  end
end
