# frozen_string_literal: true

require "spec_helper"
require "a2a/client/helpers"

RSpec.describe A2a::Client::Helpers do
  describe ".create_text_message" do
    it "creates a user message with text part" do
      message = described_class.create_text_message(text: "Hello, world!")

      expect(message).to be_a(A2a::Types::Message)
      expect(message.role).to eq(A2a::Types::Role::USER)
      expect(message.parts.length).to eq(1)
      expect(message.parts.first.root).to be_a(A2a::Types::TextPart)
      expect(message.parts.first.root.text).to eq("Hello, world!")
      expect(message.message_id).not_to be_nil
    end

    it "accepts context_id" do
      message = described_class.create_text_message(
        text: "Hello",
        context_id: "ctx-123"
      )

      expect(message.context_id).to eq("ctx-123")
    end

    it "accepts task_id" do
      message = described_class.create_text_message(
        text: "Hello",
        task_id: "task-123"
      )

      expect(message.task_id).to eq("task-123")
    end

    it "generates unique message_id" do
      message1 = described_class.create_text_message(text: "Hello")
      message2 = described_class.create_text_message(text: "World")

      expect(message1.message_id).not_to eq(message2.message_id)
    end
  end

  describe ".create_message_from_parts" do
    let(:parts) do
      [
        A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Part 1")),
        A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Part 2"))
      ]
    end

    it "creates a user message from parts" do
      message = described_class.create_message_from_parts(parts: parts)

      expect(message).to be_a(A2a::Types::Message)
      expect(message.role).to eq(A2a::Types::Role::USER)
      expect(message.parts).to eq(parts)
      expect(message.message_id).not_to be_nil
    end

    it "accepts context_id and task_id" do
      message = described_class.create_message_from_parts(
        parts: parts,
        context_id: "ctx-123",
        task_id: "task-123"
      )

      expect(message.context_id).to eq("ctx-123")
      expect(message.task_id).to eq("task-123")
    end
  end
end
