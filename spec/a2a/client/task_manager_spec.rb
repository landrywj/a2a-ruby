# frozen_string_literal: true

require "spec_helper"
require "a2a/client/task_manager"

RSpec.describe A2a::Client::TaskManager do
  let(:manager) { described_class.new }

  describe "#initialize" do
    it "initializes with empty state" do
      expect(manager.current_task).to be_nil
      expect(manager.task_id).to be_nil
      expect(manager.context_id).to be_nil
    end
  end

  describe "#get_task" do
    it "returns nil when no task_id is set" do
      expect(manager.get_task).to be_nil
    end

    it "returns current_task when task_id is set" do
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
      )
      manager.instance_variable_set(:@current_task, task)
      manager.instance_variable_set(:@task_id, "task-123")

      expect(manager.get_task).to eq(task)
    end
  end

  describe "#get_task_or_raise" do
    it "raises error when no task is set" do
      expect { manager.get_task_or_raise }.to raise_error(
        A2a::Client::InvalidStateError,
        "no current Task"
      )
    end

    it "returns task when task is set" do
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
      )
      manager.instance_variable_set(:@current_task, task)
      manager.instance_variable_set(:@task_id, "task-123")

      expect(manager.get_task_or_raise).to eq(task)
    end
  end

  describe "#save_task_event" do
    context "with Task event" do
      let(:task) do
        A2a::Types::Task.new(
          id: "task-123",
          context_id: "ctx-123",
          status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
        )
      end

      it "saves a new task" do
        result = manager.save_task_event(task)
        expect(result).to eq(task)
        expect(manager.current_task).to eq(task)
        expect(manager.task_id).to eq("task-123")
        expect(manager.context_id).to eq("ctx-123")
      end

      it "raises error if task already exists" do
        manager.save_task_event(task)
        expect do
          manager.save_task_event(task)
        end.to raise_error(
          A2a::Client::InvalidArgsError,
          "Task is already set, create new manager for new tasks."
        )
      end
    end

    context "with TaskStatusUpdateEvent" do
      let(:status_event) do
        A2a::Types::TaskStatusUpdateEvent.new(
          task_id: "task-123",
          context_id: "ctx-123",
          status: A2a::Types::TaskStatus.new(
            state: A2a::Types::TaskState::WORKING,
            message: A2a::Types::Message.new(
              role: A2a::Types::Role::AGENT,
              message_id: "msg-1",
              parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Working"))]
            )
          ),
          final: false
        )
      end

      it "creates task if it doesn't exist" do
        result = manager.save_task_event(status_event)
        expect(result).to be_a(A2a::Types::Task)
        expect(result.id).to eq("task-123")
        expect(result.status.state).to eq("working")
        expect(result.history).to include(status_event.status.message)
      end

      it "updates existing task" do
        task = A2a::Types::Task.new(
          id: "task-123",
          context_id: "ctx-123",
          status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
        )
        manager.instance_variable_set(:@current_task, task)
        manager.instance_variable_set(:@task_id, "task-123")

        result = manager.save_task_event(status_event)
        expect(result.status.state).to eq("working")
        expect(result.history).to include(status_event.status.message)
      end

      it "updates metadata" do
        status_event.metadata = { "key" => "value" }
        result = manager.save_task_event(status_event)
        expect(result.metadata).to eq({ "key" => "value" })
      end
    end

    context "with TaskArtifactUpdateEvent" do
      let(:artifact_event) do
        A2a::Types::TaskArtifactUpdateEvent.new(
          task_id: "task-123",
          context_id: "ctx-123",
          artifact: A2a::Types::Artifact.new(
            artifact_id: "art-1",
            parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Artifact content"))]
          ),
          append: false
        )
      end

      it "creates task and adds artifact" do
        result = manager.save_task_event(artifact_event)
        expect(result).to be_a(A2a::Types::Task)
        expect(result.artifacts).not_to be_nil
        expect(result.artifacts.length).to eq(1)
        expect(result.artifacts.first.artifact_id).to eq("art-1")
      end

      it "appends to existing artifact when append is true" do
        # First artifact
        manager.save_task_event(artifact_event)

        # Second artifact with append
        artifact_event2 = A2a::Types::TaskArtifactUpdateEvent.new(
          task_id: "task-123",
          context_id: "ctx-123",
          artifact: A2a::Types::Artifact.new(
            artifact_id: "art-1",
            parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "More content"))]
          ),
          append: true
        )

        result = manager.save_task_event(artifact_event2)
        expect(result.artifacts.length).to eq(1)
        expect(result.artifacts.first.parts.length).to eq(2)
      end
    end
  end

  describe "#process" do
    it "processes Task events" do
      task = A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::SUBMITTED)
      )

      result = manager.process(task)
      expect(result).to eq(task)
      expect(manager.current_task).to eq(task)
    end

    it "processes TaskStatusUpdateEvent" do
      event = A2a::Types::TaskStatusUpdateEvent.new(
        task_id: "task-123",
        context_id: "ctx-123",
        status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::WORKING),
        final: false
      )

      result = manager.process(event)
      expect(result).to eq(event)
      expect(manager.current_task).not_to be_nil
    end

    it "returns non-task events unchanged" do
      other_event = "not a task event"
      result = manager.process(other_event)
      expect(result).to eq(other_event)
    end
  end

  describe "#update_with_message" do
    let(:task) do
      A2a::Types::Task.new(
        id: "task-123",
        context_id: "ctx-123",
        status: A2a::Types::TaskStatus.new(
          state: A2a::Types::TaskState::WORKING,
          message: A2a::Types::Message.new(
            role: A2a::Types::Role::AGENT,
            message_id: "msg-1",
            parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Current"))]
          )
        )
      )
    end
    let(:new_message) do
      A2a::Types::Message.new(
        role: A2a::Types::Role::AGENT,
        message_id: "msg-2",
        parts: [A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "New"))]
      )
    end

    it "moves current status message to history and adds new message" do
      original_status_message = task.status.message
      result = manager.update_with_message(new_message, task)
      expect(result.history).to include(original_status_message)
      expect(result.history).to include(new_message)
      expect(result.status.message).to be_nil
    end

    it "adds message to history when no status message exists" do
      task.status.message = nil
      result = manager.update_with_message(new_message, task)
      expect(result.history).to include(new_message)
    end
  end
end
