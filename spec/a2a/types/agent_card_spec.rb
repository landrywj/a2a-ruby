# frozen_string_literal: true

require "spec_helper"
require "a2a/types"

RSpec.describe A2a::Types::AgentSkill do
  describe "#initialize" do
    it "creates an agent skill with all attributes" do
      skill = A2a::Types::AgentSkill.new(
        id: "skill-1",
        name: "Recipe Assistant",
        description: "Helps with cooking recipes",
        examples: ["I need a recipe for bread"],
        tags: %w[cooking recipes],
        input_modes: ["text/plain"],
        output_modes: ["text/plain"],
        security: [{ "oauth" => ["read"] }]
      )

      expect(skill.id).to eq("skill-1")
      expect(skill.name).to eq("Recipe Assistant")
      expect(skill.description).to eq("Helps with cooking recipes")
      expect(skill.examples).to eq(["I need a recipe for bread"])
      expect(skill.tags).to eq(%w[cooking recipes])
      expect(skill.input_modes).to eq(["text/plain"])
      expect(skill.output_modes).to eq(["text/plain"])
      expect(skill.security).to eq([{ "oauth" => ["read"] }])
    end

    it "handles camelCase keys" do
      skill = A2a::Types::AgentSkill.new(
        "id" => "skill-1",
        "name" => "Skill",
        "inputModes" => ["text/plain"],
        "outputModes" => ["text/html"]
      )
      expect(skill.id).to eq("skill-1")
      expect(skill.input_modes).to eq(["text/plain"])
      expect(skill.output_modes).to eq(["text/html"])
    end
  end
end

RSpec.describe A2a::Types::AgentInterface do
  describe "#initialize" do
    it "creates an agent interface" do
      interface = A2a::Types::AgentInterface.new(
        url: "https://api.example.com/a2a/v1",
        transport: A2a::Types::TransportProtocol::JSONRPC
      )

      expect(interface.url).to eq("https://api.example.com/a2a/v1")
      expect(interface.transport).to eq("JSONRPC")
    end
  end
end

RSpec.describe A2a::Types::AgentProvider do
  describe "#initialize" do
    it "creates an agent provider" do
      provider = A2a::Types::AgentProvider.new(
        organization: "Example Corp",
        url: "https://example.com"
      )

      expect(provider.organization).to eq("Example Corp")
      expect(provider.url).to eq("https://example.com")
    end
  end
end

RSpec.describe A2a::Types::AgentCapabilities do
  describe "#initialize" do
    it "creates agent capabilities" do
      capabilities = A2a::Types::AgentCapabilities.new(
        push_notifications: true,
        streaming: true,
        state_transition_history: false,
        extensions: []
      )

      expect(capabilities.push_notifications).to be true
      expect(capabilities.streaming).to be true
      expect(capabilities.state_transition_history).to eq(false)
      expect(capabilities.extensions).to eq([])
    end

    it "handles camelCase keys" do
      capabilities = A2a::Types::AgentCapabilities.new(
        "pushNotifications" => true,
        "streaming" => false,
        "stateTransitionHistory" => true
      )
      expect(capabilities.push_notifications).to be true
      expect(capabilities.streaming).to be false
      expect(capabilities.state_transition_history).to be true
    end
  end
end

RSpec.describe A2a::Types::AgentCard do
  describe "#initialize" do
    it "creates an agent card with all attributes" do
      skill = A2a::Types::AgentSkill.new(
        id: "skill-1",
        name: "Recipe Assistant",
        description: "Helps with recipes",
        tags: ["cooking"]
      )
      capabilities = A2a::Types::AgentCapabilities.new(
        push_notifications: true,
        streaming: false
      )
      provider = A2a::Types::AgentProvider.new(
        organization: "Example Corp",
        url: "https://example.com"
      )
      interface = A2a::Types::AgentInterface.new(
        url: "https://api.example.com/a2a/v1",
        transport: A2a::Types::TransportProtocol::JSONRPC
      )

      card = A2a::Types::AgentCard.new(
        name: "Recipe Agent",
        description: "An agent that helps with recipes",
        version: "1.0.0",
        url: "https://api.example.com/a2a/v1",
        preferred_transport: A2a::Types::TransportProtocol::JSONRPC,
        protocol_version: "0.3.0",
        default_input_modes: ["text/plain"],
        default_output_modes: ["text/plain"],
        skills: [skill],
        capabilities: capabilities,
        provider: provider,
        security: [{ "oauth" => ["read"] }],
        security_schemes: {},
        documentation_url: "https://docs.example.com",
        icon_url: "https://example.com/icon.png",
        additional_interfaces: [interface],
        supports_authenticated_extended_card: false
      )

      expect(card.name).to eq("Recipe Agent")
      expect(card.description).to eq("An agent that helps with recipes")
      expect(card.version).to eq("1.0.0")
      expect(card.url).to eq("https://api.example.com/a2a/v1")
      expect(card.preferred_transport).to eq("JSONRPC")
      expect(card.protocol_version).to eq("0.3.0")
      expect(card.skills.length).to eq(1)
      expect(card.capabilities.push_notifications).to be true
      expect(card.provider.organization).to eq("Example Corp")
      expect(card.additional_interfaces.length).to eq(1)
    end

    it "uses default values for preferred_transport and protocol_version" do
      skill = A2a::Types::AgentSkill.new(
        id: "skill-1",
        name: "Skill",
        description: "Description",
        tags: ["tag"]
      )
      card = A2a::Types::AgentCard.new(
        name: "Agent",
        description: "Description",
        version: "1.0.0",
        url: "https://api.example.com/a2a/v1",
        default_input_modes: ["text/plain"],
        default_output_modes: ["text/plain"],
        skills: [skill]
      )

      expect(card.preferred_transport).to eq("JSONRPC")
      expect(card.protocol_version).to eq("0.3.0")
    end

    it "handles camelCase keys" do
      skill = A2a::Types::AgentSkill.new(
        id: "skill-1",
        name: "Skill",
        description: "Description",
        tags: ["tag"]
      )
      card = A2a::Types::AgentCard.new(
        "name" => "Agent",
        "description" => "Description",
        "version" => "1.0.0",
        "url" => "https://api.example.com/a2a/v1",
        "preferredTransport" => "GRPC",
        "protocolVersion" => "0.3.0",
        "defaultInputModes" => ["text/plain"],
        "defaultOutputModes" => ["text/plain"],
        "skills" => [skill]
      )

      expect(card.name).to eq("Agent")
      expect(card.preferred_transport).to eq("GRPC")
      expect(card.protocol_version).to eq("0.3.0")
    end

    it "creates nested objects from hashes" do
      card = A2a::Types::AgentCard.new(
        name: "Agent",
        description: "Description",
        version: "1.0.0",
        url: "https://api.example.com/a2a/v1",
        default_input_modes: ["text/plain"],
        default_output_modes: ["text/plain"],
        skills: [{
          "id" => "skill-1",
          "name" => "Skill",
          "description" => "Description",
          "tags" => ["tag"]
        }],
        capabilities: {
          "pushNotifications" => true
        }
      )

      expect(card.skills.first).to be_a(A2a::Types::AgentSkill)
      expect(card.capabilities).to be_a(A2a::Types::AgentCapabilities)
      expect(card.capabilities.push_notifications).to be true
    end
  end

  describe "#to_h" do
    it "serializes agent card to hash" do
      skill = A2a::Types::AgentSkill.new(
        id: "skill-1",
        name: "Skill",
        description: "Description",
        tags: ["tag"]
      )
      card = A2a::Types::AgentCard.new(
        name: "Agent",
        description: "Description",
        version: "1.0.0",
        url: "https://api.example.com/a2a/v1",
        default_input_modes: ["text/plain"],
        default_output_modes: ["text/plain"],
        skills: [skill]
      )
      hash = card.to_h

      expect(hash["name"]).to eq("Agent")
      expect(hash["url"]).to eq("https://api.example.com/a2a/v1")
      expect(hash["preferredTransport"]).to eq("JSONRPC")
      expect(hash["skills"]).to be_an(Array)
      expect(hash["skills"].first["id"]).to eq("skill-1")
    end
  end
end
