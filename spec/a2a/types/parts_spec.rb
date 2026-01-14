# frozen_string_literal: true

require "spec_helper"
require "a2a/types"

RSpec.describe A2a::Types do
  describe "TextPart" do
    it "creates a text part with text content" do
      part = A2a::Types::TextPart.new(text: "Hello, world!")
      expect(part.kind).to eq("text")
      expect(part.text).to eq("Hello, world!")
    end

    it "initializes from hash with string keys" do
      part = A2a::Types::TextPart.new("text" => "Hello")
      expect(part.text).to eq("Hello")
    end

    it "allows metadata" do
      part = A2a::Types::TextPart.new(text: "Hello", metadata: { "key" => "value" })
      expect(part.metadata).to eq({ "key" => "value" })
    end

    it "serializes to hash with camelCase" do
      part = A2a::Types::TextPart.new(text: "Hello", metadata: { "key" => "value" })
      hash = part.to_h
      expect(hash["kind"]).to eq("text")
      expect(hash["text"]).to eq("Hello")
      expect(hash["metadata"]).to eq({ "key" => "value" })
    end

    it "converts to JSON" do
      part = A2a::Types::TextPart.new(text: "Hello")
      json = part.to_json
      parsed = JSON.parse(json)
      expect(parsed["kind"]).to eq("text")
      expect(parsed["text"]).to eq("Hello")
    end
  end

  describe "FileWithBytes" do
    it "creates a file with base64 bytes" do
      file = A2a::Types::FileWithBytes.new(
        bytes: "SGVsbG8gV29ybGQ=",
        mime_type: "text/plain",
        name: "hello.txt"
      )
      expect(file.bytes).to eq("SGVsbG8gV29ybGQ=")
      expect(file.mime_type).to eq("text/plain")
      expect(file.name).to eq("hello.txt")
    end

    it "handles optional fields" do
      file = A2a::Types::FileWithBytes.new(bytes: "data")
      expect(file.bytes).to eq("data")
      expect(file.mime_type).to be_nil
      expect(file.name).to be_nil
    end

    it "initializes from hash with camelCase keys" do
      file = A2a::Types::FileWithBytes.new("bytes" => "data", "mimeType" => "text/plain")
      expect(file.bytes).to eq("data")
      expect(file.mime_type).to eq("text/plain")
    end

    it "serializes to hash" do
      file = A2a::Types::FileWithBytes.new(bytes: "data", mime_type: "text/plain", name: "file.txt")
      hash = file.to_h
      expect(hash["bytes"]).to eq("data")
      expect(hash["mimeType"]).to eq("text/plain")
      expect(hash["name"]).to eq("file.txt")
    end
  end

  describe "FileWithUri" do
    it "creates a file with URI" do
      file = A2a::Types::FileWithUri.new(
        uri: "https://example.com/file.txt",
        mime_type: "text/plain",
        name: "file.txt"
      )
      expect(file.uri).to eq("https://example.com/file.txt")
      expect(file.mime_type).to eq("text/plain")
      expect(file.name).to eq("file.txt")
    end

    it "handles optional fields" do
      file = A2a::Types::FileWithUri.new(uri: "https://example.com/file.txt")
      expect(file.uri).to eq("https://example.com/file.txt")
      expect(file.mime_type).to be_nil
    end

    it "serializes to hash" do
      file = A2a::Types::FileWithUri.new(uri: "https://example.com/file.txt", mime_type: "text/plain")
      hash = file.to_h
      expect(hash["uri"]).to eq("https://example.com/file.txt")
      expect(hash["mimeType"]).to eq("text/plain")
    end
  end

  describe "FilePart" do
    it "creates a file part with FileWithBytes" do
      file_data = A2a::Types::FileWithBytes.new(bytes: "data", mime_type: "text/plain")
      part = A2a::Types::FilePart.new(file: file_data)
      expect(part.kind).to eq("file")
      expect(part.file).to eq(file_data)
      expect(part.file.bytes).to eq("data")
    end

    it "creates a file part with FileWithUri" do
      file_data = A2a::Types::FileWithUri.new(uri: "https://example.com/file.txt")
      part = A2a::Types::FilePart.new(file: file_data)
      expect(part.kind).to eq("file")
      expect(part.file.uri).to eq("https://example.com/file.txt")
    end

    it "creates from hash with bytes" do
      part = A2a::Types::FilePart.new(file: { bytes: "data", mimeType: "text/plain" })
      expect(part.kind).to eq("file")
      expect(part.file).to be_a(A2a::Types::FileWithBytes)
      expect(part.file.bytes).to eq("data")
    end

    it "creates from hash with uri" do
      part = A2a::Types::FilePart.new(file: { uri: "https://example.com/file.txt" })
      expect(part.kind).to eq("file")
      expect(part.file).to be_a(A2a::Types::FileWithUri)
      expect(part.file.uri).to eq("https://example.com/file.txt")
    end

    it "allows metadata" do
      file_data = A2a::Types::FileWithBytes.new(bytes: "data")
      part = A2a::Types::FilePart.new(file: file_data, metadata: { "key" => "value" })
      expect(part.metadata).to eq({ "key" => "value" })
    end

    it "serializes to hash" do
      file_data = A2a::Types::FileWithBytes.new(bytes: "data", mime_type: "text/plain")
      part = A2a::Types::FilePart.new(file: file_data)
      hash = part.to_h
      expect(hash["kind"]).to eq("file")
      expect(hash["file"]).to be_a(Hash)
      expect(hash["file"]["bytes"]).to eq("data")
    end
  end

  describe "DataPart" do
    it "creates a data part with hash data" do
      data = { "key" => "value", "number" => 42 }
      part = A2a::Types::DataPart.new(data: data)
      expect(part.kind).to eq("data")
      expect(part.data).to eq(data)
    end

    it "allows metadata" do
      data = { "key" => "value" }
      part = A2a::Types::DataPart.new(data: data, metadata: { "meta" => "value" })
      expect(part.data).to eq(data)
      expect(part.metadata).to eq({ "meta" => "value" })
    end

    it "initializes from hash with string keys" do
      part = A2a::Types::DataPart.new("data" => { "key" => "value" })
      expect(part.data).to eq({ "key" => "value" })
    end

    it "serializes to hash" do
      data = { "key" => "value" }
      part = A2a::Types::DataPart.new(data: data)
      hash = part.to_h
      expect(hash["kind"]).to eq("data")
      expect(hash["data"]).to eq(data)
    end
  end

  describe "Part" do
    it "wraps a TextPart" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      expect(part.root).to eq(text_part)
      expect(part.root.text).to eq("Hello")
    end

    it "creates TextPart from hash" do
      part = A2a::Types::Part.new(root: { kind: "text", text: "Hello" })
      expect(part.root).to be_a(A2a::Types::TextPart)
      expect(part.root.text).to eq("Hello")
    end

    it "creates FilePart from hash" do
      part = A2a::Types::Part.new(root: { kind: "file", file: { bytes: "data" } })
      expect(part.root).to be_a(A2a::Types::FilePart)
      expect(part.root.file).to be_a(A2a::Types::FileWithBytes)
    end

    it "creates DataPart from hash" do
      part = A2a::Types::Part.new(root: { kind: "data", data: { "key" => "value" } })
      expect(part.root).to be_a(A2a::Types::DataPart)
      expect(part.root.data).to eq({ "key" => "value" })
    end

    it "defaults to TextPart when kind is not specified" do
      part = A2a::Types::Part.new(root: { text: "Hello" })
      expect(part.root).to be_a(A2a::Types::TextPart)
      expect(part.root.text).to eq("Hello")
    end

    it "serializes to hash" do
      text_part = A2a::Types::TextPart.new(text: "Hello")
      part = A2a::Types::Part.new(root: text_part)
      hash = part.to_h
      expect(hash["kind"]).to eq("text")
      expect(hash["text"]).to eq("Hello")
    end

    it "handles direct hash initialization" do
      part = A2a::Types::Part.new(kind: "text", text: "Hello")
      expect(part.root).to be_a(A2a::Types::TextPart)
      expect(part.root.text).to eq("Hello")
    end
  end
end
