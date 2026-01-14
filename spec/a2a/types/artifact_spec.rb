# frozen_string_literal: true

require "spec_helper"
require "a2a/types"

RSpec.describe A2a::Types::Artifact do
  describe "#initialize" do
    it "creates an artifact with all attributes" do
      part = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Result"))
      artifact = described_class.new(
        artifact_id: "art-123",
        name: "Result Document",
        description: "The final result",
        parts: [part],
        extensions: ["ext-1"],
        metadata: { "key" => "value" }
      )

      expect(artifact.artifact_id).to eq("art-123")
      expect(artifact.name).to eq("Result Document")
      expect(artifact.description).to eq("The final result")
      expect(artifact.parts.length).to eq(1)
      expect(artifact.extensions).to eq(["ext-1"])
      expect(artifact.metadata).to eq({ "key" => "value" })
    end

    it "creates an artifact with minimal attributes" do
      part = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Result"))
      artifact = described_class.new(
        artifact_id: "art-123",
        parts: [part]
      )

      expect(artifact.artifact_id).to eq("art-123")
      expect(artifact.name).to be_nil
      expect(artifact.description).to be_nil
      expect(artifact.extensions).to be_nil
    end

    it "handles multiple parts" do
      part1 = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Part 1"))
      part2 = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Part 2"))
      artifact = described_class.new(
        artifact_id: "art-123",
        parts: [part1, part2]
      )
      expect(artifact.parts.length).to eq(2)
    end

    it "creates Part objects from hashes" do
      artifact = described_class.new(
        artifact_id: "art-123",
        parts: [{ root: { kind: "text", text: "Result" } }]
      )
      expect(artifact.parts.first).to be_a(A2a::Types::Part)
      expect(artifact.parts.first.root.text).to eq("Result")
    end

    it "handles camelCase keys" do
      artifact = described_class.new(
        "artifactId" => "art-123",
        "name" => "Result",
        "parts" => [{ "root" => { "kind" => "text", "text" => "Result" } }]
      )
      expect(artifact.artifact_id).to eq("art-123")
      expect(artifact.name).to eq("Result")
    end
  end

  describe "#to_h" do
    it "serializes artifact to hash" do
      part = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Result"))
      artifact = described_class.new(
        artifact_id: "art-123",
        name: "Result",
        parts: [part]
      )
      hash = artifact.to_h

      expect(hash["artifactId"]).to eq("art-123")
      expect(hash["name"]).to eq("Result")
      expect(hash["parts"]).to be_an(Array)
      expect(hash["parts"].first["kind"]).to eq("text")
    end
  end

  describe "#to_json" do
    it "serializes artifact to JSON" do
      part = A2a::Types::Part.new(root: A2a::Types::TextPart.new(text: "Result"))
      artifact = described_class.new(
        artifact_id: "art-123",
        name: "Result",
        parts: [part]
      )
      json = artifact.to_json
      parsed = JSON.parse(json)

      expect(parsed["artifactId"]).to eq("art-123")
      expect(parsed["name"]).to eq("Result")
    end
  end
end
