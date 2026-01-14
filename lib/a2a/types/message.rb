# frozen_string_literal: true

module A2a
  module Types
    # Represents a single message in the conversation between a user and an agent
    class Message < BaseModel
      attr_accessor :kind, :message_id, :role, :parts, :task_id, :context_id,
                    :reference_task_ids, :extensions

      def initialize(attributes = {})
        super
        @kind = "message"
        @message_id = attributes[:message_id] || attributes["messageId"]
        @role = attributes[:role] || attributes["role"]
      @parts = if attributes[:parts] || attributes["parts"]
                 (attributes[:parts] || attributes["parts"]).map do |part|
                   part.is_a?(Part) ? part : Part.new(part)
                 end
               end
        @task_id = attributes[:task_id] || attributes["taskId"]
        @context_id = attributes[:context_id] || attributes["contextId"]
        @reference_task_ids = attributes[:reference_task_ids] || attributes["referenceTaskIds"]
        @extensions = attributes[:extensions] || attributes["extensions"]
      end
    end
  end
end
