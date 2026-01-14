# frozen_string_literal: true

require "securerandom"
require_relative "../types"
require_relative "../utils/message"

module A2a
  module Client
    # Helper methods for creating client messages and common operations
    module Helpers
      # Creates a text message for sending to an agent.
      #
      # This is a convenience method for creating a user message with a single text part.
      #
      # @param text [String] The text content of the message
      # @param context_id [String, nil] The context ID for the message
      # @param task_id [String, nil] The task ID for the message
      # @return [Types::Message] A new Message object with role 'user'
      def self.create_text_message(text:, context_id: nil, task_id: nil)
        Types::Message.new(
          role: Types::Role::USER,
          parts: [Types::Part.new(root: Types::TextPart.new(text: text))],
          message_id: SecureRandom.uuid,
          task_id: task_id,
          context_id: context_id
        )
      end

      # Creates a message from parts.
      #
      # @param parts [Array<Types::Part>] The list of Part objects for the message content
      # @param context_id [String, nil] The context ID for the message
      # @param task_id [String, nil] The task ID for the message
      # @return [Types::Message] A new Message object with role 'user'
      def self.create_message_from_parts(parts:, context_id: nil, task_id: nil)
        Types::Message.new(
          role: Types::Role::USER,
          parts: parts,
          message_id: SecureRandom.uuid,
          task_id: task_id,
          context_id: context_id
        )
      end
    end
  end
end
