# frozen_string_literal: true

require "spec_helper"
require "a2a/types"
require "a2a/utils"

RSpec.describe A2a::Utils::Message do
  describe ".new_agent_text_message" do
    it "creates an agent message with text" do
      message = described_class.new_agent_text_message(text: "Hello from agent")
      expect(message.role).to eq("agent")
      expect(message.parts.length).to eq(1)
      expect(message.parts.first.root.text).to eq("Hello from agent")
      expect(message.message_id).to be_a(String)
      expect(message.message_id.length).to be > 0
    end

    it "generates a UUID for message_id" do
      message1 = described_class.new_agent_text_message(text: "Hello")
      message2 = described_class.new_agent_text_message(text: "Hello")
      expect(message1.message_id).not_to eq(message2.message_id)
    end

    it "accepts optional context_id" do
      message = described_class.new_agent_text_message(
        text: "Hello",
        context_id: "ctx-123"
      )
      expect(message.context_id).to eq("ctx-123")
    end

    it "accepts optional task_id" do
      message = described_class.new_agent_text_message(
        text: "Hello",
        task_id: "task-123"
      )
      expect(message.task_id).to eq("task-123")
    end

    it "handles empty text" do
      message = described_class.new_agent_text_message(text: "")
      expect(message.parts.first.root.text).to eq("")
    end
  end

  describe ".new_agent_parts_message" do
    it "creates an agent message with parts" do
      part1 = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))
      part2 = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "World"))
      message = described_class.new_agent_parts_message(parts: [part1, part2])

      expect(message.role).to eq("agent")
      expect(message.parts.length).to eq(2)
      expect(message.parts.first.root.text).to eq("Hello")
      expect(message.parts.last.root.text).to eq("World")
    end

    it "generates a UUID for message_id" do
      part = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))
      message1 = described_class.new_agent_parts_message(parts: [part])
      message2 = described_class.new_agent_parts_message(parts: [part])
      expect(message1.message_id).not_to eq(message2.message_id)
    end

    it "accepts optional context_id and task_id" do
      part = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))
      message = described_class.new_agent_parts_message(
        parts: [part],
        context_id: "ctx-123",
        task_id: "task-123"
      )
      expect(message.context_id).to eq("ctx-123")
      expect(message.task_id).to eq("task-123")
    end
  end

  describe ".get_message_text" do
    it "extracts text from a single text part" do
      part = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part]
      )
      text = described_class.get_message_text(message)
      expect(text).to eq("Hello")
    end

    it "extracts text from multiple text parts" do
      part1 = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))
      part2 = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "World"))
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part1, part2]
      )
      text = described_class.get_message_text(message)
      expect(text).to eq("Hello\nWorld")
    end

    it "uses custom delimiter" do
      part1 = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))
      part2 = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "World"))
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part1, part2]
      )
      text = described_class.get_message_text(message, delimiter: " | ")
      expect(text).to eq("Hello | World")
    end

    it "ignores non-text parts" do
      text_part = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))
      data_part = A2a::Types::Part.new(root: A2a::Types::DataPart.new(data: { "key" => "value" }))
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [text_part, data_part]
      )
      text = described_class.get_message_text(message)
      expect(text).to eq("Hello")
    end

    it "returns empty string when no text parts" do
      data_part = A2a::Types::Part.new(root: A2a::Types::DataPart.new(data: { "key" => "value" }))
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [data_part]
      )
      text = described_class.get_message_text(message)
      expect(text).to eq("")
    end

    it "handles nil parts" do
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: nil
      )
      text = described_class.get_message_text(message)
      expect(text).to eq("")
    end

    it "handles empty parts array" do
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: []
      )
      text = described_class.get_message_text(message)
      expect(text).to eq("")
    end
  end
end

RSpec.describe A2a::Utils::Task do
  describe ".new_task" do
    it "creates a new task from a message" do
      text_part = A2a::Types::TextPart.new(text: "Create a task")
      part = A2a::Types::Part.new(root: text_part)
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part]
      )
      task = described_class.new_task(message)

      expect(task.status.state).to eq("submitted")
      expect(task.history.length).to eq(1)
      expect(task.history.first).to eq(message)
      expect(task.kind).to eq("task")
    end

    it "generates task_id if not provided in message" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part]
      )
      task = described_class.new_task(message)
      expect(task.id).to be_a(String)
      expect(task.id.length).to be > 0
    end

    it "uses task_id from message if provided" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        task_id: "task-123",
        parts: [part]
      )
      task = described_class.new_task(message)
      expect(task.id).to eq("task-123")
    end

    it "generates context_id if not provided in message" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part]
      )
      task = described_class.new_task(message)
      expect(task.context_id).to be_a(String)
      expect(task.context_id.length).to be > 0
    end

    it "uses context_id from message if provided" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        context_id: "ctx-123",
        parts: [part]
      )
      task = described_class.new_task(message)
      expect(task.context_id).to eq("ctx-123")
    end

    it "raises TypeError if message role is nil" do
      message = A2a::Types::Message.new(
        role: nil,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
      expect { described_class.new_task(message) }.to raise_error(TypeError, /role cannot be nil/)
    end

    it "raises ArgumentError if message parts are empty" do
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: []
      )
      expect { described_class.new_task(message) }.to raise_error(ArgumentError, /parts cannot be empty/)
    end

    it "raises ArgumentError if message parts are nil" do
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: nil
      )
      expect { described_class.new_task(message) }.to raise_error(ArgumentError, /parts cannot be empty/)
    end

    it "raises ArgumentError if TextPart content is empty" do
      text_part = A2a::Types::TextPart.new(text: "")
      part = A2a::Types::Part.new(root: text_part)
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [part]
      )
      expect { described_class.new_task(message) }.to raise_error(ArgumentError, /content cannot be empty/)
    end
  end

  describe ".completed_task" do
    it "creates a completed task with artifacts" do
      artifact = A2a::Types::Artifact.new(
        artifact_id: "art-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Result"))]
      )
      task = described_class.completed_task(
        task_id: "task-123",
        context_id: "ctx-123",
        artifacts: [artifact]
      )

      expect(task.id).to eq("task-123")
      expect(task.context_id).to eq("ctx-123")
      expect(task.status.state).to eq("completed")
      expect(task.artifacts.length).to eq(1)
      expect(task.artifacts.first).to eq(artifact)
    end

    it "includes history if provided" do
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
      artifact = A2a::Types::Artifact.new(
        artifact_id: "art-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Result"))]
      )
      task = described_class.completed_task(
        task_id: "task-123",
        context_id: "ctx-123",
        artifacts: [artifact],
        history: [message]
      )

      expect(task.history.length).to eq(1)
      expect(task.history.first).to eq(message)
    end

    it "uses empty history if not provided" do
      artifact = A2a::Types::Artifact.new(
        artifact_id: "art-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Result"))]
      )
      task = described_class.completed_task(
        task_id: "task-123",
        context_id: "ctx-123",
        artifacts: [artifact]
      )

      expect(task.history).to eq([])
    end

    it "raises ArgumentError if artifacts is empty" do
      expect do
        described_class.completed_task(
          task_id: "task-123",
          context_id: "ctx-123",
          artifacts: []
        )
      end.to raise_error(ArgumentError, /artifacts must be a non-empty list/)
    end

    it "raises ArgumentError if artifacts is nil" do
      expect do
        described_class.completed_task(
          task_id: "task-123",
          context_id: "ctx-123",
          artifacts: nil
        )
      end.to raise_error(ArgumentError, /artifacts must be a non-empty list/)
    end

    it "raises ArgumentError if artifacts contains non-Artifact objects" do
      expect do
        described_class.completed_task(
          task_id: "task-123",
          context_id: "ctx-123",
          artifacts: ["not an artifact"]
        )
      end.to raise_error(ArgumentError, /artifacts must be a non-empty list/)
    end
  end

  describe ".apply_history_length" do
    it "returns task unchanged if history_length is nil" do
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::WORKING)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        history: [message]
      )

      result = described_class.apply_history_length(task, nil)
      expect(result.history.length).to eq(1)
    end

    it "returns task unchanged if history_length is 0" do
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::WORKING)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        history: [message]
      )

      result = described_class.apply_history_length(task, 0)
      expect(result.history.length).to eq(1)
    end

    it "limits history to specified length" do
      messages = (1..5).map do |i|
        A2a::Types::Message.new(
          role: A2a::Types::Role::USER,
          message_id: "msg-#{i}",
          parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Message #{i}"))]
        )
      end
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::WORKING)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        history: messages
      )

      result = described_class.apply_history_length(task, 2)
      expect(result.history.length).to eq(2)
      expect(result.history.first.message_id).to eq("msg-4")
      expect(result.history.last.message_id).to eq("msg-5")
    end

    it "returns all history if history_length exceeds history size" do
      messages = (1..3).map do |i|
        A2a::Types::Message.new(
          role: A2a::Types::Role::USER,
          message_id: "msg-#{i}",
          parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Message #{i}"))]
        )
      end
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::WORKING)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        history: messages
      )

      result = described_class.apply_history_length(task, 10)
      expect(result.history.length).to eq(3)
    end

    it "handles task with nil history" do
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::WORKING)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        history: nil
      )

      result = described_class.apply_history_length(task, 2)
      expect(result.history).to be_nil
    end

    it "preserves other task attributes" do
      message = A2a::Types::Message.new(
        role: A2a::Types::Role::USER,
        message_id: "msg-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))]
      )
      artifact = A2a::Types::Artifact.new(
        artifact_id: "art-123",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Result"))]
      )
      status = A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::WORKING)
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: status,
        history: [message],
        artifacts: [artifact],
        metadata: { "key" => "value" }
      )

      result = described_class.apply_history_length(task, 1)
      expect(result.id).to eq("task-123")
      expect(result.context_id).to eq("ctx-123")
      expect(result.artifacts.length).to eq(1)
      expect(result.metadata).to eq({ "key" => "value" })
    end
  end
end

RSpec.describe A2a::Utils::Parts do
  describe ".get_text_parts" do
    it "extracts text from text parts" do
      parts = [
        A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello")),
        A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "World"))
      ]
      texts = described_class.get_text_parts(parts)
      expect(texts).to eq(%w[Hello World])
    end

    it "ignores non-text parts" do
      parts = [
        A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello")),
        A2a::Types::Part.new(root: A2a::Types::DataPart.new(data: { "key" => "value" }))
      ]
      texts = described_class.get_text_parts(parts)
      expect(texts).to eq(["Hello"])
    end

    it "returns empty array for nil parts" do
      texts = described_class.get_text_parts(nil)
      expect(texts).to eq([])
    end

    it "returns empty array when no text parts" do
      parts = [
        A2a::Types::Part.new(root: A2a::Types::DataPart.new(data: { "key" => "value" }))
      ]
      texts = described_class.get_text_parts(parts)
      expect(texts).to eq([])
    end
  end

  describe ".get_data_parts" do
    it "extracts data from data parts" do
      parts = [
        A2a::Types::Part.new(root: A2a::Types::DataPart.new(data: { "key1" => "value1" })),
        A2a::Types::Part.new(root: A2a::Types::DataPart.new(data: { "key2" => "value2" }))
      ]
      data = described_class.get_data_parts(parts)
      expect(data).to eq([{ "key1" => "value1" }, { "key2" => "value2" }])
    end

    it "ignores non-data parts" do
      parts = [
        A2a::Types::Part.new(root: A2a::Types::DataPart.new(data: { "key" => "value" })),
        A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))
      ]
      data = described_class.get_data_parts(parts)
      expect(data).to eq([{ "key" => "value" }])
    end

    it "returns empty array for nil parts" do
      data = described_class.get_data_parts(nil)
      expect(data).to eq([])
    end
  end

  describe ".get_file_parts" do
    it "extracts file data from file parts" do
      file1 = A2a::Types::FileWithBytes.new(bytes: "data1", mime_type: "text/plain")
      file2 = A2a::Types::FileWithUri.new(uri: "https://example.com/file.txt")
      parts = [
        A2a::Types::Part.new(root: A2a::Types::FilePart.new(file: file1)),
        A2a::Types::Part.new(root: A2a::Types::FilePart.new(file: file2))
      ]
      files = described_class.get_file_parts(parts)
      expect(files.length).to eq(2)
      expect(files.first).to eq(file1)
      expect(files.last).to eq(file2)
    end

    it "ignores non-file parts" do
      parts = [
        A2a::Types::Part.new(root: A2a::Types::FilePart.new(file: A2a::Types::FileWithBytes.new(bytes: "data"))),
        A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Hello"))
      ]
      files = described_class.get_file_parts(parts)
      expect(files.length).to eq(1)
      expect(files.first.bytes).to eq("data")
    end

    it "returns empty array for nil parts" do
      files = described_class.get_file_parts(nil)
      expect(files).to eq([])
    end
  end
end
