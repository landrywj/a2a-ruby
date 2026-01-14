# frozen_string_literal: true

require_relative "../types"
require_relative "../utils/task"
require_relative "errors"

module A2a
  module Client
    # Helps manage a task's lifecycle during execution of a request.
    #
    # Responsible for retrieving, saving, and updating the `Task` object based on
    # events received from the agent.
    class TaskManager
      attr_reader :current_task, :task_id, :context_id

      def initialize
        @current_task = nil
        @task_id = nil
        @context_id = nil
      end

      # Retrieves the current task object.
      #
      # If `task_id` is set, it returns `current_task` otherwise nil.
      #
      # @return [Types::Task, nil] The Task object if found, otherwise nil
      def get_task
        return nil unless @task_id

        @current_task
      end

      # Retrieves the current task object.
      #
      # @return [Types::Task] The Task object
      # @raise [InvalidStateError] If there is no current known Task
      def get_task_or_raise
        task = get_task
        raise InvalidStateError, "no current Task" unless task

        task
      end

      # Processes a task-related event and saves the updated task state.
      #
      # @param event [Types::Task, Types::TaskStatusUpdateEvent, Types::TaskArtifactUpdateEvent] The task-related event
      # @return [Types::Task, nil] The updated Task object after processing the event
      # @raise [InvalidArgsError] If the task ID in the event conflicts with the TaskManager's ID
      def save_task_event(event)
        if event.is_a?(Types::Task)
          raise InvalidArgsError, "Task is already set, create new manager for new tasks." if @current_task

          save_task(event)
          return event
        end

        task_id_from_event = event.is_a?(Types::Task) ? event.id : event.task_id
        @task_id ||= task_id_from_event
        @context_id ||= event.context_id

        task = @current_task
        task ||= Types::Task.new(
          status: Types::TaskStatus.new(state: Types::TaskState::UNKNOWN),
          id: task_id_from_event,
          context_id: @context_id || ""
        )

        if event.is_a?(Types::TaskStatusUpdateEvent)
          if event.status.message
            task.history ||= []
            task.history << event.status.message
          end
          if event.metadata
            task.metadata ||= {}
            task.metadata.merge!(event.metadata)
          end
          task.status = event.status
        elsif event.is_a?(Types::TaskArtifactUpdateEvent)
          Utils::Task.append_artifact_to_task(task, event)
        end

        @current_task = task
        task
      end

      # Processes an event, updates the task state if applicable, stores it, and returns the event.
      #
      # @param event [Object] The event object received from the agent
      # @return [Object] The same event object that was processed
      def process(event)
        save_task_event(event) if event.is_a?(Types::Task) || event.is_a?(Types::TaskStatusUpdateEvent) || event.is_a?(Types::TaskArtifactUpdateEvent)

        event
      end

      # Updates a task object adding a new message to its history.
      #
      # @param message [Types::Message] The new Message to add to the history
      # @param task [Types::Task] The Task object to update
      # @return [Types::Task] The updated Task object
      def update_with_message(message, task)
        if task.status.message
          task.history ||= []
          task.history << task.status.message
          task.status.message = nil
        end
        task.history ||= []
        task.history << message
        @current_task = task
        task
      end

      private

      def save_task(task)
        @current_task = task
        return if @task_id

        @task_id = task.id
        @context_id = task.context_id
      end
    end
  end
end
