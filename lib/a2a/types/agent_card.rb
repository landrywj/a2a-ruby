# frozen_string_literal: true

module A2a
  module Types
    # Represents a distinct capability or function that an agent can perform
    class AgentSkill < BaseModel
      attr_accessor :id, :name, :description, :examples, :tags, :input_modes, :output_modes, :security

      def initialize(attributes = {})
        super
        @id = attributes[:id] || attributes["id"]
        @name = attributes[:name] || attributes["name"]
        @description = attributes[:description] || attributes["description"]
        @examples = attributes[:examples] || attributes["examples"]
        @tags = attributes[:tags] || attributes["tags"]
        @input_modes = attributes[:input_modes] || attributes["inputModes"]
        @output_modes = attributes[:output_modes] || attributes["outputModes"]
        @security = attributes[:security] || attributes["security"]
      end
    end

    # Declares a combination of a target URL and a transport protocol
    class AgentInterface < BaseModel
      attr_accessor :url, :transport

      def initialize(attributes = {})
        super
        @url = attributes[:url] || attributes["url"]
        @transport = attributes[:transport] || attributes["transport"]
      end
    end

    # Represents the service provider of an agent
    class AgentProvider < BaseModel
      attr_accessor :organization, :url

      def initialize(attributes = {})
        super
        @organization = attributes[:organization] || attributes["organization"]
        @url = attributes[:url] || attributes["url"]
      end
    end

    # Defines optional capabilities supported by an agent
    class AgentCapabilities < BaseModel
      attr_accessor :push_notifications, :streaming, :state_transition_history, :extensions

      def initialize(attributes = {})
        super
        # Handle false values explicitly - check if key exists, not just truthiness
        @push_notifications = attributes.key?(:push_notifications) ? attributes[:push_notifications] : (attributes.key?("pushNotifications") ? attributes["pushNotifications"] : nil)
        @streaming = attributes.key?(:streaming) ? attributes[:streaming] : (attributes.key?("streaming") ? attributes["streaming"] : nil)
        @state_transition_history = attributes.key?(:state_transition_history) ? attributes[:state_transition_history] : (attributes.key?("stateTransitionHistory") ? attributes["stateTransitionHistory"] : nil)
        @extensions = attributes[:extensions] || attributes["extensions"]
      end
    end

    # The AgentCard is a self-describing manifest for an agent
    class AgentCard < BaseModel
      attr_accessor :name, :description, :version, :url, :preferred_transport, :protocol_version,
                    :default_input_modes, :default_output_modes, :skills, :capabilities,
                    :provider, :security, :security_schemes, :documentation_url, :icon_url,
                    :additional_interfaces, :supports_authenticated_extended_card, :signatures

      def initialize(attributes = {})
        super
        @name = attributes[:name] || attributes["name"]
        @description = attributes[:description] || attributes["description"]
        @version = attributes[:version] || attributes["version"]
        @url = attributes[:url] || attributes["url"]
        @preferred_transport = attributes[:preferred_transport] || attributes["preferredTransport"] || "JSONRPC"
        @protocol_version = attributes[:protocol_version] || attributes["protocolVersion"] || "0.3.0"
        @default_input_modes = attributes[:default_input_modes] || attributes["defaultInputModes"]
        @default_output_modes = attributes[:default_output_modes] || attributes["defaultOutputModes"]
        skills_data = attributes[:skills] || attributes["skills"]
        @skills = if skills_data
                    skills_data.map do |skill|
                      skill.is_a?(AgentSkill) ? skill : AgentSkill.new(skill)
                    end
                  end
        capabilities_data = attributes[:capabilities] || attributes["capabilities"]
        @capabilities = if capabilities_data
                          capabilities_data.is_a?(AgentCapabilities) ? capabilities_data : AgentCapabilities.new(capabilities_data)
                        end
        provider_data = attributes[:provider] || attributes["provider"]
        @provider = if provider_data
                      provider_data.is_a?(AgentProvider) ? provider_data : AgentProvider.new(provider_data)
                    end
        @security = attributes[:security] || attributes["security"]
        @security_schemes = attributes[:security_schemes] || attributes["securitySchemes"]
        @documentation_url = attributes[:documentation_url] || attributes["documentationUrl"]
        @icon_url = attributes[:icon_url] || attributes["iconUrl"]
        interfaces_data = attributes[:additional_interfaces] || attributes["additionalInterfaces"]
        @additional_interfaces = if interfaces_data
                                   interfaces_data.map do |interface|
                                     interface.is_a?(AgentInterface) ? interface : AgentInterface.new(interface)
                                   end
                                 end
        @supports_authenticated_extended_card = attributes[:supports_authenticated_extended_card] || attributes["supportsAuthenticatedExtendedCard"]
        @signatures = attributes[:signatures] || attributes["signatures"]
      end
    end
  end
end
