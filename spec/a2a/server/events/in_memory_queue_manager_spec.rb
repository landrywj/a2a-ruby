# frozen_string_literal: true

require "spec_helper"
require "a2a/server/events/in_memory_queue_manager"
require "a2a/server/events/event_queue"

RSpec.describe A2a::Server::Events::InMemoryQueueManager do
  let(:manager) { described_class.new }
  let(:task_id) { "task-123" }
  let(:queue) { A2a::Server::Events::EventQueue.new }

  describe "#add" do
    it "adds a queue for a task" do
      manager.add(task_id, queue)
      expect(manager.get(task_id)).to eq(queue)
    end

    it "raises error if queue already exists" do
      manager.add(task_id, queue)
      expect { manager.add(task_id, queue) }.to raise_error(A2a::Server::Events::TaskQueueExists)
    end
  end

  describe "#get" do
    it "returns nil for non-existent task" do
      expect(manager.get(task_id)).to be_nil
    end

    it "returns queue for existing task" do
      manager.add(task_id, queue)
      expect(manager.get(task_id)).to eq(queue)
    end
  end

  describe "#tap" do
    it "returns nil for non-existent task" do
      expect(manager.tap(task_id)).to be_nil
    end

    it "creates child queue for existing task" do
      manager.add(task_id, queue)
      child = manager.tap(task_id)
      expect(child).to be_a(A2a::Server::Events::EventQueue)
      expect(child).not_to eq(queue)
    end
  end

  describe "#close" do
    it "raises error for non-existent task" do
      expect { manager.close(task_id) }.to raise_error(A2a::Server::Events::NoTaskQueue)
    end

    it "closes and removes queue" do
      manager.add(task_id, queue)
      manager.close(task_id)
      expect(queue.closed?).to be true
      expect(manager.get(task_id)).to be_nil
    end
  end

  describe "#create_or_tap" do
    it "creates new queue if task doesn't exist" do
      new_queue = manager.create_or_tap(task_id)
      expect(new_queue).to be_a(A2a::Server::Events::EventQueue)
      expect(manager.get(task_id)).to eq(new_queue)
    end

    it "taps existing queue if task exists" do
      manager.add(task_id, queue)
      child = manager.create_or_tap(task_id)
      expect(child).to be_a(A2a::Server::Events::EventQueue)
      expect(child).not_to eq(queue)
    end
  end
end
