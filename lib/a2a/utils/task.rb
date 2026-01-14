# frozen_string_literal: true

require "securerandom"

module A2a
  module Utils
    # Utility functions for creating A2A Task objects
    module Task
      # Creates a new Task object from an initial user message.
      #
      # Generates task and context IDs if not provided in the message.
      #
      # @param request [Types::Message] The initial Message object from the user
      # @return [Types::Task] A new Task object initialized with 'submitted' status
      # @raise [TypeError] If the message role is nil
      # @raise [ValueError] If the message parts are empty or if any part has empty content
      def self.new_task(request)
        raise TypeError, "Message role cannot be nil" if request.role.nil?
        raise ArgumentError, "Message parts cannot be empty" if request.parts.nil? || request.parts.empty?

        request.parts.each do |part|
          if part.root.is_a?(Types::TextPart) && (part.root.text.nil? || part.root.text.empty?)
            raise ArgumentError, "TextPart content cannot be empty"
          end
        end

        Types::Task.new(
          id: request.task_id || SecureRandom.uuid,
          context_id: request.context_id || SecureRandom.uuid,
          status: Types::TaskStatus.new(state: Types::TaskState::SUBMITTED),
          history: [request]
        )
      end

      # Creates a Task object in the 'completed' state.
      #
      # Useful for constructing a final Task representation when the agent
      # finishes and produces artifacts.
      #
      # @param task_id [String] The ID of the task
      # @param context_id [String] The context ID of the task
      # @param artifacts [Array<Types::Artifact>] A list of Artifact objects produced by the task
      # @param history [Array<Types::Message>, nil] An optional list of Message objects
      # @return [Types::Task] A Task object with status set to 'completed'
      # @raise [ArgumentError] If artifacts is empty or contains non-Artifact objects
      def self.completed_task(task_id:, context_id:, artifacts:, history: nil)
        if artifacts.nil? || artifacts.empty? || !artifacts.all? { |a| a.is_a?(Types::Artifact) }
          raise ArgumentError, "artifacts must be a non-empty list of Artifact objects"
        end

        Types::Task.new(
          id: task_id,
          context_id: context_id,
          status: Types::TaskStatus.new(state: Types::TaskState::COMPLETED),
          artifacts: artifacts,
          history: history || []
        )
      end

      # Applies history_length parameter on task and returns a new task object.
      #
      # @param task [Types::Task] The original task object with complete history
      # @param history_length [Integer, nil] History length configuration value
      # @return [Types::Task] A new task object with limited history
      def self.apply_history_length(task, history_length)
        return task if history_length.nil? || history_length <= 0 || task.history.nil? || task.history.empty?

        # Limit history to the most recent N messages
        # If history_length exceeds history size, we get all history
        limited_history = task.history[-history_length..] || task.history
        
        # Build attributes hash, preserving all original attributes
        task_attrs = {
          id: task.id,
          context_id: task.context_id,
          status: task.status,
          history: limited_history
        }
        task_attrs[:artifacts] = task.artifacts if task.artifacts
        task_attrs[:metadata] = task.metadata if task.metadata
        
        Types::Task.new(task_attrs)
      end
    end
  end
end
