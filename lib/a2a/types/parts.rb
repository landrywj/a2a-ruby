# frozen_string_literal: true

module A2a
  module Types
    # Base class for message/artifact parts
    class PartBase < BaseModel
      attr_accessor :metadata

      def initialize(attributes = {})
        super
        @metadata = attributes[:metadata] || attributes["metadata"]
      end
    end

    # Represents a text segment within a message or artifact
    class TextPart < PartBase
      attr_accessor :kind, :text

      def initialize(attributes = {})
        super
        @kind = "text"
        @text = attributes[:text] || attributes["text"]
      end
    end

    # Represents a file with content provided directly as base64-encoded string
    class FileWithBytes < BaseModel
      attr_accessor :bytes, :mime_type, :name

      def initialize(attributes = {})
        super
        @bytes = attributes[:bytes] || attributes["bytes"]
        @mime_type = attributes[:mime_type] || attributes["mimeType"]
        @name = attributes[:name] || attributes["name"]
      end
    end

    # Represents a file with content located at a specific URI
    class FileWithUri < BaseModel
      attr_accessor :uri, :mime_type, :name

      def initialize(attributes = {})
        super
        @uri = attributes[:uri] || attributes["uri"]
        @mime_type = attributes[:mime_type] || attributes["mimeType"]
        @name = attributes[:name] || attributes["name"]
      end
    end

    # Represents a file segment within a message or artifact
    class FilePart < PartBase
      attr_accessor :kind, :file

      def initialize(attributes = {})
        super
        @kind = "file"
        file_data = attributes[:file] || attributes["file"]
        @file = if file_data.is_a?(Hash)
                  if file_data.key?(:bytes) || file_data.key?("bytes")
                    FileWithBytes.new(file_data)
                  elsif file_data.key?(:uri) || file_data.key?("uri")
                    FileWithUri.new(file_data)
                  else
                    file_data
                  end
                else
                  file_data
                end
      end
    end

    # Represents a structured data segment (e.g., JSON) within a message or artifact
    class DataPart < PartBase
      attr_accessor :kind, :data

      def initialize(attributes = {})
        super
        @kind = "data"
        @data = attributes[:data] || attributes["data"]
      end
    end

    # Discriminated union representing a part of a message or artifact
    class Part < BaseModel
      attr_accessor :root

      def initialize(attributes = {})
        super
        root_data = attributes[:root] || attributes["root"] || attributes

        # If root_data is already a PartBase instance or a Part instance, use it directly
        if root_data.is_a?(PartBase)
          @root = root_data
        elsif root_data.is_a?(Part)
          @root = root_data.root
        else
          # Otherwise, treat it as a hash and create the appropriate part type
          kind = root_data[:kind] || root_data["kind"] if root_data.respond_to?(:[]) || root_data.is_a?(Hash)
          @root = case kind
                  when "text"
                    TextPart.new(root_data)
                  when "file"
                    FilePart.new(root_data)
                  when "data"
                    DataPart.new(root_data)
                  else
                    # Default to TextPart if kind is not specified or unknown
                    TextPart.new(root_data)
                  end
        end
      end

      def to_h
        @root.to_h
      end
    end
  end
end
