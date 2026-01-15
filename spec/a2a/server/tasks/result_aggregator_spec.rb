# frozen_string_literal: true

require "spec_helper"
require "a2a/server/tasks/result_aggregator"
require "a2a/server/events/event_consumer"
require "a2a/server/events/event_queue"
require "a2a/types"

RSpec.describe A2a::Server::Tasks::ResultAggregator do
  let(:task_manager) { double("TaskManager", process: nil, get_task: nil) }
  let(:aggregator) { described_class.new(task_manager) }
  let(:queue) { A2a::Server::Events::EventQueue.new }
  let(:consumer) { A2a::Server::Events::EventConsumer.new(queue) }

  describe "#consume_and_emit" do
    let(:status_update) do
      A2a::Types::TaskStatusUpdateEvent.new(
        task_id: "task-1",
        status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::WORKING)
      )
    end

    it "processes and emits events" do
      queue.enqueue_event(status_update)
      # Close after enqueuing so consumer can process it
      Thread.new do
        sleep 0.01
        queue.close(immediate: true)
      end

      events = []
      begin
        aggregator.consume_and_emit(consumer) { |e| events << e }
      rescue ThreadError
        # Queue closed, that's expected
      end

      expect(events).to include(status_update)
      expect(task_manager).to have_received(:process).with(status_update)
    end
  end

  describe "#consume_all" do
    let(:message) { A2a::Types::Message.new(parts: []) }

    it "returns message if message is final event" do
      queue.enqueue_event(message)
      result = aggregator.consume_all(consumer)
      expect(result).to eq(message)
    end

    it "returns task from task manager if no message" do
      task = A2a::Types::Task.new(id: "task-1", status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::COMPLETED))
      queue.enqueue_event(task)
      allow(task_manager).to receive(:get_task).and_return(task)

      result = aggregator.consume_all(consumer)
      expect(result).to eq(task)
    end
  end

  describe "#current_result" do
    it "returns message if set" do
      message = A2a::Types::Message.new(parts: [])
      aggregator.instance_variable_set(:@message, message)
      expect(aggregator.current_result).to eq(message)
    end

    it "returns task from task manager if no message" do
      task = A2a::Types::Task.new(id: "task-1", status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::COMPLETED))
      allow(task_manager).to receive(:get_task).and_return(task)
      expect(aggregator.current_result).to eq(task)
    end
  end
end
