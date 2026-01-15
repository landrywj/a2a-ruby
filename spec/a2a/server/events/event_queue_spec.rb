# frozen_string_literal: true

require "spec_helper"
require "a2a/server/events/event_queue"
require "a2a/types"

RSpec.describe A2a::Server::Events::EventQueue do
  let(:queue) { described_class.new }

  describe "#initialize" do
    it "creates a queue with default max size" do
      expect(queue.max_queue_size).to eq(A2a::Server::Events::DEFAULT_MAX_QUEUE_SIZE)
    end

    it "creates a queue with custom max size" do
      custom_queue = described_class.new(max_queue_size: 512)
      expect(custom_queue.max_queue_size).to eq(512)
    end

    it "raises error for invalid max size" do
      expect { described_class.new(max_queue_size: 0) }.to raise_error(ArgumentError)
      expect { described_class.new(max_queue_size: -1) }.to raise_error(ArgumentError)
    end
  end

  describe "#enqueue_event" do
    let(:message) { A2a::Types::Message.new(parts: []) }

    it "enqueues an event" do
      queue.enqueue_event(message)
      expect(queue.empty?).to be false
    end

    it "does not enqueue after closing" do
      queue.close(immediate: true)
      queue.enqueue_event(message)
      expect(queue.empty?).to be true
    end
  end

  describe "#dequeue_event" do
    let(:message) { A2a::Types::Message.new(parts: []) }

    it "dequeues an event" do
      queue.enqueue_event(message)
      event = queue.dequeue_event
      expect(event).to eq(message)
    end

    it "raises error when dequeuing from empty queue with no_wait" do
      expect { queue.dequeue_event(no_wait: true) }.to raise_error(ThreadError)
    end

    it "blocks when dequeuing from empty queue" do
      start_time = Time.now
      Thread.new do
        sleep 0.1
        queue.enqueue_event(message)
      end
      event = queue.dequeue_event
      expect(event).to eq(message)
      expect(Time.now - start_time).to be >= 0.1
    end
  end

  describe "#tap" do
    let(:message) { A2a::Types::Message.new(parts: []) }

    it "creates a child queue that receives events" do
      child = queue.tap
      queue.enqueue_event(message)
      expect(child.dequeue_event(no_wait: true)).to eq(message)
    end

    it "child queue receives future events" do
      message1 = A2a::Types::Message.new(parts: [])
      message2 = A2a::Types::Message.new(parts: [])
      queue.enqueue_event(message1)
      child = queue.tap
      queue.enqueue_event(message2)
      expect(child.dequeue_event(no_wait: true)).to eq(message2)
    end
  end

  describe "#close" do
    let(:message) { A2a::Types::Message.new(parts: []) }

    it "closes the queue" do
      queue.close
      expect(queue.closed?).to be true
    end

    it "closes immediately and clears events" do
      queue.enqueue_event(message)
      queue.close(immediate: true)
      expect(queue.empty?).to be true
      expect(queue.closed?).to be true
    end

    it "closes child queues" do
      child = queue.tap
      queue.close(immediate: true)
      expect(child.closed?).to be true
    end
  end

  describe "#clear_events" do
    let(:message) { A2a::Types::Message.new(parts: []) }

    it "clears all events" do
      queue.enqueue_event(message)
      queue.enqueue_event(message)
      cleared = queue.clear_events
      expect(cleared).to eq(2)
      expect(queue.empty?).to be true
    end
  end
end
