# frozen_string_literal: true

require "securerandom"

module A2a
  module Utils
    # Utility functions for creating and handling A2A Message objects
    module Message
      # Creates a new agent message containing a single TextPart.
      #
      # @param text [String] The text content of the message
      # @param context_id [String, nil] The context ID for the message
      # @param task_id [String, nil] The task ID for the message
      # @return [Types::Message] A new Message object with role 'agent'
      def self.new_agent_text_message(text:, context_id: nil, task_id: nil)
        Types::Message.new(
          role: Types::Role::AGENT,
          parts: [Types::Part.new(root: Types::TextPart.new(text: text))],
          message_id: SecureRandom.uuid,
          task_id: task_id,
          context_id: context_id
        )
      end

      # Creates a new agent message containing a list of Parts.
      #
      # @param parts [Array<Types::Part>] The list of Part objects for the message content
      # @param context_id [String, nil] The context ID for the message
      # @param task_id [String, nil] The task ID for the message
      # @return [Types::Message] A new Message object with role 'agent'
      def self.new_agent_parts_message(parts:, context_id: nil, task_id: nil)
        Types::Message.new(
          role: Types::Role::AGENT,
          parts: parts,
          message_id: SecureRandom.uuid,
          task_id: task_id,
          context_id: context_id
        )
      end

      # Extracts and joins all text content from a Message's parts.
      #
      # @param message [Types::Message] The Message object
      # @param delimiter [String] The string to use when joining text from multiple TextParts
      # @return [String] A single string containing all text content, or an empty string if no text parts are found
      def self.get_message_text(message, delimiter: "\n")
        get_text_parts(message.parts).join(delimiter)
      end

      private

      def self.get_text_parts(parts)
        return [] if parts.nil?

        parts.select { |part| part.root.is_a?(Types::TextPart) }
             .map { |part| part.root.text }
      end
    end
  end
end
