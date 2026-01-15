# frozen_string_literal: true

require_relative "queue_manager"
require_relative "event_queue"

module A2a
  module Server
    module Events
      # InMemoryQueueManager is used for a single binary management.
      #
      # This implements the QueueManager interface using in-memory storage for event
      # queues. It requires all incoming interactions for a given task ID to hit the
      # same binary instance.
      #
      # This implementation is suitable for single-instance deployments but needs
      # a distributed approach for scalable deployments.
      class InMemoryQueueManager < QueueManager
        def initialize
          @task_queue = {}
          @lock = Mutex.new
        end

        # Adds a new event queue for a task ID.
        #
        # @param task_id [String] The task ID
        # @param queue [EventQueue] The event queue to add
        # @raise [TaskQueueExists] If a queue for the given task_id already exists
        def add(task_id, queue)
          @lock.synchronize do
            raise TaskQueueExists, "Queue for task #{task_id} already exists" if @task_queue.key?(task_id)

            @task_queue[task_id] = queue
          end
        end

        # Retrieves the event queue for a task ID.
        #
        # @param task_id [String] The task ID
        # @return [EventQueue, nil] The event queue for the task ID, or nil if not found
        def get(task_id)
          @lock.synchronize do
            @task_queue[task_id]
          end
        end

        # Creates a child event queue (tap) for an existing task ID.
        #
        # @param task_id [String] The task ID
        # @return [EventQueue, nil] A new child event queue, or nil if the task ID is not found
        def tap(task_id)
          @lock.synchronize do
            return nil unless @task_queue.key?(task_id)

            @task_queue[task_id].tap
          end
        end

        # Closes and removes the event queue for a task ID.
        #
        # @param task_id [String] The task ID
        # @raise [NoTaskQueue] If no queue exists for the given task_id
        def close(task_id)
          @lock.synchronize do
            raise NoTaskQueue, "No queue exists for task #{task_id}" unless @task_queue.key?(task_id)

            queue = @task_queue.delete(task_id)
            queue.close
          end
        end

        # Creates a new event queue for a task ID if one doesn't exist, otherwise taps the existing one.
        #
        # @param task_id [String] The task ID
        # @return [EventQueue] A new or child event queue instance for the task_id
        def create_or_tap(task_id)
          @lock.synchronize do
            if @task_queue.key?(task_id)
              @task_queue[task_id].tap
            else
              queue = EventQueue.new
              @task_queue[task_id] = queue
              queue
            end
          end
        end
      end
    end
  end
end
