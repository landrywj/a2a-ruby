# frozen_string_literal: true

module A2a
  module Rails
    # ActiveJob for executing agent logic in the background.
    #
    # This job runs the agent executor and publishes events to the event queue.
    # It's designed to be enqueued when a new message is received, allowing
    # the web worker to return immediately while the agent processes the request.
    #
    # Usage:
    #   A2a::Rails::AgentExecutionJob.perform_later(agent_executor_class, request_context_data, queue_id)
    class AgentExecutionJob < (defined?(ActiveJob::Base) ? ActiveJob::Base : Object)
      queue_as :a2a_agent_execution if respond_to?(:queue_as)

      # Performs agent execution.
      #
      # @param agent_executor_class [String] The class name of the AgentExecutor
      # @param request_context_data [Hash] Serialized request context
      # @param queue_id [String] The queue identifier for publishing events
      def perform(agent_executor_class, request_context_data, queue_id)
        agent_executor = agent_executor_class.constantize.new
        request_context = deserialize_request_context(request_context_data)
        queue = retrieve_queue(queue_id)

        return unless queue

        begin
          agent_executor.execute(request_context, queue)
        ensure
          queue.close
        end
      end

      private

      def deserialize_request_context(data)
        # Deserialize the request context from hash
        # In a real implementation, this would reconstruct the RequestContext object
        # Using Hash instead of OpenStruct per RuboCop
        data
      end

      def retrieve_queue(queue_id)
        # This should retrieve the queue from a persistent store (Redis, etc.)
        # For now, this is a placeholder
        raise NotImplementedError, "Queue retrieval from persistent store must be implemented"
      end
    end
  end
end
