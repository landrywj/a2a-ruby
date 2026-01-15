# frozen_string_literal: true

require "spec_helper"
require "a2a/server/events/event_queue"
require "a2a/server/events/event_consumer"
require "a2a/types"

RSpec.describe A2a::Server::Events::EventConsumer do
  let(:queue) { A2a::Server::Events::EventQueue.new }
  let(:consumer) { described_class.new(queue) }

  describe "#consume_one" do
    let(:message) { A2a::Types::Message.new(parts: []) }

    it "consumes one event" do
      queue.enqueue_event(message)
      event = consumer.consume_one
      expect(event).to eq(message)
    end

    it "raises error when queue is empty" do
      expect { consumer.consume_one }.to raise_error(A2a::Server::ServerError)
    end
  end

  describe "#consume_all" do
    let(:message) { A2a::Types::Message.new(parts: []) }

    it "consumes all events until final event" do
      # Message is a final event, so it stops after the first event
      status_update = A2a::Types::TaskStatusUpdateEvent.new(
        task_id: "task-1",
        status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::WORKING)
      )
      task = A2a::Types::Task.new(
        id: "task-1",
        status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::COMPLETED)
      )

      queue.enqueue_event(status_update)
      queue.enqueue_event(task)

      events = []
      consumer.consume_all { |e| events << e }

      expect(events).to include(status_update, task)
      expect(queue.closed?).to be true
    end

    it "stops on final event (Message)" do
      queue.enqueue_event(message)
      events = []
      consumer.consume_all { |e| events << e }

      expect(events).to eq([message])
      expect(queue.closed?).to be true
    end

    it "stops on final event (completed Task)" do
      task = A2a::Types::Task.new(
        id: "task-1",
        status: A2a::Types::TaskStatus.new(state: A2a::Types::TaskState::COMPLETED)
      )

      queue.enqueue_event(task)
      events = []
      consumer.consume_all { |e| events << e }

      expect(events).to eq([task])
      expect(queue.closed?).to be true
    end
  end

  describe "#agent_task_callback" do
    it "stores exception to be raised" do
      exception = StandardError.new("test error")
      consumer.agent_task_callback(exception)

      expect { consumer.consume_all { |_e| } }.to raise_error(StandardError, "test error")
    end
  end
end
