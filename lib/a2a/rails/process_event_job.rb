# frozen_string_literal: true

module A2a
  module Rails
    # ActiveJob for processing A2A events in the background.
    #
    # This job handles background consumption of events when a client disconnects
    # during streaming, ensuring events are still processed and persisted.
    #
    # Usage:
    #   A2a::Rails::ProcessEventJob.perform_later(task_id, queue_id, task_manager_id)
    class ProcessEventJob < (defined?(ActiveJob::Base) ? ActiveJob::Base : Object)
      if respond_to?(:queue_as)
        queue_as :a2a_events
      end

      # Performs background event consumption.
      #
      # @param task_id [String] The task ID
      # @param queue_id [String] The queue identifier (for retrieving the queue)
      # @param task_manager_id [String] The task manager identifier
      def perform(task_id, queue_id, task_manager_id)
        require_relative "../server/events/event_consumer"
        require_relative "../server/tasks/result_aggregator"

        # Retrieve the queue and task manager from storage
        # In a real implementation, these would be stored in Redis or database
        queue = retrieve_queue(queue_id)
        task_manager = retrieve_task_manager(task_manager_id)

        return unless queue && task_manager

        consumer = Server::Events::EventConsumer.new(queue)
        result_aggregator = Server::Tasks::ResultAggregator.new(task_manager)

        begin
          result_aggregator.consume_all(consumer)
        rescue StandardError => e
          # Log error (in production, use Rails.logger)
          if defined?(Rails) && Rails.respond_to?(:logger)
            Rails.logger.error("ProcessEventJob failed for task #{task_id}: #{e.message}")
          end
          raise
        end
      end

      private

      def retrieve_queue(queue_id)
        # This should retrieve the queue from a persistent store (Redis, etc.)
        # For now, this is a placeholder
        raise NotImplementedError, "Queue retrieval from persistent store must be implemented"
      end

      def retrieve_task_manager(task_manager_id)
        # This should retrieve the task manager from a persistent store
        # For now, this is a placeholder
        raise NotImplementedError, "TaskManager retrieval from persistent store must be implemented"
      end
    end
  end
end
