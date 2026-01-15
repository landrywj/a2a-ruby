# frozen_string_literal: true

require_relative "event_queue"

module A2a
  module Server
    module Events
      # Interface for managing the event queue lifecycles per task.
      class QueueManager
        # Adds a new event queue associated with a task ID.
        #
        # @param task_id [String] The task ID
        # @param queue [EventQueue] The event queue to add
        # @raise [TaskQueueExists] If a queue for the given task_id already exists
        def add(task_id, queue)
          raise NotImplementedError, "add must be implemented"
        end

        # Retrieves the event queue for a task ID.
        #
        # @param task_id [String] The task ID
        # @return [EventQueue, nil] The event queue for the task ID, or nil if not found
        def get(task_id)
          raise NotImplementedError, "get must be implemented"
        end

        # Creates a child event queue (tap) for an existing task ID.
        #
        # @param task_id [String] The task ID
        # @return [EventQueue, nil] A new child event queue, or nil if the task ID is not found
        def tap(task_id)
          raise NotImplementedError, "tap must be implemented"
        end

        # Closes and removes the event queue for a task ID.
        #
        # @param task_id [String] The task ID
        # @raise [NoTaskQueue] If no queue exists for the given task_id
        def close(task_id)
          raise NotImplementedError, "close must be implemented"
        end

        # Creates a queue if one doesn't exist, otherwise taps the existing one.
        #
        # @param task_id [String] The task ID
        # @return [EventQueue] A new or child event queue instance for the task_id
        def create_or_tap(task_id)
          raise NotImplementedError, "create_or_tap must be implemented"
        end
      end

      # Exception raised when attempting to add a queue for a task ID that already exists.
      class TaskQueueExists < StandardError; end

      # Exception raised when attempting to access a queue for a task ID that doesn't exist.
      class NoTaskQueue < StandardError; end
    end
  end
end
