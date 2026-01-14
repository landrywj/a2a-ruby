# frozen_string_literal: true

require_relative "message"
require_relative "artifact"

module A2a
  module Types
    # Represents the status of a task at a specific point in time
    class TaskStatus < BaseModel
      attr_accessor :state, :message, :timestamp

      def initialize(attributes = {})
        super
        @state = attributes[:state] || attributes["state"]
        message_data = attributes[:message] || attributes["message"]
        @message = if message_data
                     message_data.is_a?(Message) ? message_data : Message.new(message_data)
                   end
        @timestamp = attributes[:timestamp] || attributes["timestamp"]
      end
    end

    # Represents a single, stateful operation or conversation between a client and an agent
    class Task < BaseModel
      attr_accessor :id, :context_id, :kind, :status, :history, :artifacts

      def initialize(attributes = {})
        super
        @id = attributes[:id] || attributes["id"]
        @context_id = attributes[:context_id] || attributes["contextId"]
        @kind = "task"
        status_data = attributes[:status] || attributes["status"]
        @status = if status_data
                    status_data.is_a?(TaskStatus) ? status_data : TaskStatus.new(status_data)
                  end
        history_data = attributes[:history] || attributes["history"]
        @history = if history_data
                     history_data.map do |msg|
                       msg.is_a?(Message) ? msg : Message.new(msg)
                     end
                   end
        artifacts_data = attributes[:artifacts] || attributes["artifacts"]
        @artifacts = if artifacts_data
                       artifacts_data.map do |artifact|
                         artifact.is_a?(Artifact) ? artifact : Artifact.new(artifact)
                       end
                     end
      end
    end
  end
end
