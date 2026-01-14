# frozen_string_literal: true

module A2a
  module Utils
    # Utility functions for creating and handling A2A Parts objects
    module Parts
      # Extracts text content from all TextPart objects in a list of Parts.
      #
      # @param parts [Array<Types::Part>] A list of Part objects
      # @return [Array<String>] A list of strings containing the text content from any TextPart objects found
      def self.get_text_parts(parts)
        return [] if parts.nil?

        parts.select { |part| part.root.is_a?(Types::TextPart) }
             .map { |part| part.root.text }
      end

      # Extracts dictionary data from all DataPart objects in a list of Parts.
      #
      # @param parts [Array<Types::Part>] A list of Part objects
      # @return [Array<Hash>] A list of dictionaries containing the data from any DataPart objects found
      def self.get_data_parts(parts)
        return [] if parts.nil?

        parts.select { |part| part.root.is_a?(Types::DataPart) }
             .map { |part| part.root.data }
      end

      # Extracts file data from all FilePart objects in a list of Parts.
      #
      # @param parts [Array<Types::Part>] A list of Part objects
      # @return [Array] A list of FileWithBytes or FileWithUri objects containing the file data
      def self.get_file_parts(parts)
        return [] if parts.nil?

        parts.select { |part| part.root.is_a?(Types::FilePart) }
             .map { |part| part.root.file }
      end
    end
  end
end
