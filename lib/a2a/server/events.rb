# frozen_string_literal: true

require_relative "events/event_queue"
require_relative "events/event_consumer"
require_relative "events/queue_manager"
require_relative "events/in_memory_queue_manager"

module A2a
  module Server
    # Events module for managing event queues and consumers.
    #
    # This module provides infrastructure for streaming events from agent execution
    # to clients, including EventQueue for buffering, EventConsumer for reading,
    # and QueueManager for managing queue lifecycles.
    module Events
    end
  end
end
