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
      attr_accessor :id, :context_id, :kind, :status, :history, :artifacts, :metadata

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
        @history = history_data&.map do |msg|
          msg.is_a?(Message) ? msg : Message.new(msg)
        end
        artifacts_data = attributes[:artifacts] || attributes["artifacts"]
        @artifacts = artifacts_data&.map do |artifact|
          artifact.is_a?(Artifact) ? artifact : Artifact.new(artifact)
        end
        @metadata = attributes[:metadata] || attributes["metadata"]
      end
    end

    # An event sent by the agent to notify the client of a change in a task's status.
    class TaskStatusUpdateEvent < BaseModel
      attr_accessor :kind, :task_id, :context_id, :status, :final, :metadata

      def initialize(attributes = {})
        super
        @kind = "status-update"
        @task_id = attributes[:task_id] || attributes["taskId"]
        @context_id = attributes[:context_id] || attributes["contextId"]
        status_data = attributes[:status] || attributes["status"]
        @status = if status_data
                    status_data.is_a?(TaskStatus) ? status_data : TaskStatus.new(status_data)
                  end
        @final = attributes[:final] || attributes["final"] || false
        @metadata = attributes[:metadata] || attributes["metadata"]
      end
    end

    # An event sent by the agent to notify the client that an artifact has been generated or updated.
    class TaskArtifactUpdateEvent < BaseModel
      attr_accessor :kind, :task_id, :context_id, :artifact, :append, :last_chunk, :metadata

      def initialize(attributes = {})
        super
        @kind = "artifact-update"
        @task_id = attributes[:task_id] || attributes["taskId"]
        @context_id = attributes[:context_id] || attributes["contextId"]
        artifact_data = attributes[:artifact] || attributes["artifact"]
        @artifact = if artifact_data
                      artifact_data.is_a?(Artifact) ? artifact_data : Artifact.new(artifact_data)
                    end
        # Handle false values explicitly - check if key exists, not just truthiness
        @append = attributes.key?(:append) ? attributes[:append] : (attributes.key?("append") ? attributes["append"] : nil)
        @last_chunk = attributes.key?(:last_chunk) ? attributes[:last_chunk] : (attributes.key?("lastChunk") ? attributes["lastChunk"] : nil)
        @metadata = attributes[:metadata] || attributes["metadata"]
      end
    end
  end
end
