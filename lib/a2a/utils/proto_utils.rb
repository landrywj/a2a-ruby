# frozen_string_literal: true

# Proto conversion utilities for converting between Ruby types and protobuf messages.
#
# Note: This module requires the A2A protobuf files to be generated from the
# A2A protocol specification. See README for instructions on generating proto files.
#
# The generated proto files should be placed in lib/a2a/grpc/ and should include:
# - a2a_pb2.rb (generated from a2a.proto)
# - a2a_services_pb.rb (generated gRPC service stubs)

require "json"
require_relative "../types"

module A2a
  module Utils
    # Regexp patterns for matching task resource names
    TASK_NAME_MATCH = %r{\Atasks/([^/]+)\z}
    TASK_PUSH_CONFIG_NAME_MATCH = %r{\Atasks/([^/]+)/pushNotificationConfigs/([^/]+)\z}

    # Converts Ruby types to protobuf types
    class ToProto
      class << self
        # Converts a Message to a protobuf Message
        def message(msg)
          return nil if msg.nil?

          # NOTE: This assumes A2a::Grpc::A2aPb2::Message exists
          # The actual proto file needs to be generated from the A2A protocol specification
          proto_class = get_proto_class("Message")
          proto_class.new(
            message_id: msg.message_id,
            content: msg.parts&.map { |p| part(p) } || [],
            context_id: msg.context_id || "",
            task_id: msg.task_id || "",
            role: role(msg.role),
            metadata: metadata(msg.metadata),
            extensions: msg.extensions || []
          )
        end

        # Converts a hash to a protobuf Struct
        def metadata(metadata_hash)
          return nil if metadata_hash.nil? || metadata_hash.empty?

          proto_class = get_proto_class("Struct")
          struct = proto_class.new
          metadata_hash.each do |key, value|
            struct[key] = convert_value_to_struct_value(value)
          end
          struct
        end

        # Converts a Part to a protobuf Part
        def part(part)
          proto_class = get_proto_class("Part")
          case part.root
          when Types::TextPart
            proto_class.new(
              text: part.root.text,
              metadata: metadata(part.root.metadata)
            )
          when Types::FilePart
            proto_class.new(
              file: file(part.root.file),
              metadata: metadata(part.root.metadata)
            )
          when Types::DataPart
            proto_class.new(
              data: data(part.root.data),
              metadata: metadata(part.root.metadata)
            )
          else
            raise ArgumentError, "Unsupported part type: #{part.root.class}"
          end
        end

        # Converts a data hash to a protobuf DataPart
        def data(data_hash)
          proto_class = get_proto_class("DataPart")
          proto_class.new(data: metadata(data_hash))
        end

        # Converts a FileWithUri or FileWithBytes to a protobuf FilePart
        def file(file_obj)
          proto_class = get_proto_class("FilePart")
          case file_obj
          when Types::FileWithUri
            proto_class.new(
              file_with_uri: file_obj.uri,
              mime_type: file_obj.mime_type,
              name: file_obj.name
            )
          when Types::FileWithBytes
            proto_class.new(
              file_with_bytes: file_obj.bytes.encode("utf-8"),
              mime_type: file_obj.mime_type,
              name: file_obj.name
            )
          else
            raise ArgumentError, "Unsupported file type: #{file_obj.class}"
          end
        end

        # Converts a Task to a protobuf Task
        def task(task)
          proto_class = get_proto_class("Task")
          proto_class.new(
            id: task.id,
            context_id: task.context_id,
            status: task_status(task.status),
            artifacts: task.artifacts&.map { |a| artifact(a) } || [],
            history: task.history&.map { |h| message(h) } || [],
            metadata: metadata(task.metadata)
          )
        end

        # Converts a TaskStatus to a protobuf TaskStatus
        def task_status(status)
          proto_class = get_proto_class("TaskStatus")
          proto_class.new(
            state: task_state(status.state),
            update: message(status.message)
          )
        end

        # Converts a TaskState string to a protobuf TaskState enum
        def task_state(state)
          proto_class = get_proto_class("TaskState")
          case state
          when Types::TaskState::SUBMITTED
            proto_class::TASK_STATE_SUBMITTED
          when Types::TaskState::WORKING
            proto_class::TASK_STATE_WORKING
          when Types::TaskState::COMPLETED
            proto_class::TASK_STATE_COMPLETED
          when Types::TaskState::CANCELED
            proto_class::TASK_STATE_CANCELLED
          when Types::TaskState::FAILED
            proto_class::TASK_STATE_FAILED
          when Types::TaskState::INPUT_REQUIRED
            proto_class::TASK_STATE_INPUT_REQUIRED
          when Types::TaskState::AUTH_REQUIRED
            proto_class::TASK_STATE_AUTH_REQUIRED
          else
            proto_class::TASK_STATE_UNSPECIFIED
          end
        end

        # Converts an Artifact to a protobuf Artifact
        def artifact(artifact)
          proto_class = get_proto_class("Artifact")
          proto_class.new(
            artifact_id: artifact.artifact_id,
            description: artifact.description,
            metadata: metadata(artifact.metadata),
            name: artifact.name,
            parts: artifact.parts&.map { |p| part(p) } || [],
            extensions: artifact.extensions || []
          )
        end

        # Converts a Role string to a protobuf Role enum
        def role(role_str)
          proto_class = get_proto_class("Role")
          case role_str
          when Types::Role::USER
            proto_class::ROLE_USER
          when Types::Role::AGENT
            proto_class::ROLE_AGENT
          else
            proto_class::ROLE_UNSPECIFIED
          end
        end

        # Converts a MessageSendParams to a protobuf SendMessageRequest
        def message_send_request(params)
          proto_class = get_proto_class("SendMessageRequest")
          proto_class.new(
            request: message(params.message),
            configuration: message_send_configuration(params.configuration),
            metadata: metadata(params.metadata)
          )
        end

        # Converts a MessageSendConfiguration to a protobuf SendMessageConfiguration
        def message_send_configuration(config)
          proto_class = get_proto_class("SendMessageConfiguration")
          return proto_class.new if config.nil?

          proto_class.new(
            accepted_output_modes: config.accepted_output_modes || [],
            push_notification: config.push_notification_config ? push_notification_config(config.push_notification_config) : nil,
            history_length: config.history_length,
            blocking: config.blocking || false
          )
        end

        # Converts a PushNotificationConfig to a protobuf PushNotificationConfig
        def push_notification_config(config)
          proto_class = get_proto_class("PushNotificationConfig")
          proto_class.new(
            id: config.id || "",
            url: config.url,
            token: config.token,
            authentication: config.authentication ? authentication_info(config.authentication) : nil
          )
        end

        # Converts a PushNotificationAuthenticationInfo to a protobuf AuthenticationInfo
        def authentication_info(info)
          proto_class = get_proto_class("AuthenticationInfo")
          proto_class.new(
            schemes: info.schemes || [],
            credentials: info.credentials || {}
          )
        end

        # Converts a TaskStatusUpdateEvent to a protobuf TaskStatusUpdateEvent
        def task_status_update_event(event)
          proto_class = get_proto_class("TaskStatusUpdateEvent")
          proto_class.new(
            task_id: event.task_id,
            context_id: event.context_id,
            status: task_status(event.status),
            metadata: metadata(event.metadata),
            final: event.final || false
          )
        end

        # Converts a TaskArtifactUpdateEvent to a protobuf TaskArtifactUpdateEvent
        def task_artifact_update_event(event)
          proto_class = get_proto_class("TaskArtifactUpdateEvent")
          proto_class.new(
            task_id: event.task_id,
            context_id: event.context_id,
            artifact: artifact(event.artifact),
            metadata: metadata(event.metadata),
            append: event.append || false,
            last_chunk: event.last_chunk || false
          )
        end

        # Converts a Task, Message, or event to a protobuf StreamResponse
        def stream_response(event)
          proto_class = get_proto_class("StreamResponse")
          case event
          when Types::Message
            proto_class.new(msg: message(event))
          when Types::Task
            proto_class.new(task: task(event))
          when Types::TaskStatusUpdateEvent
            proto_class.new(status_update: task_status_update_event(event))
          when Types::TaskArtifactUpdateEvent
            proto_class.new(artifact_update: task_artifact_update_event(event))
          else
            raise ArgumentError, "Unsupported event type: #{event.class}"
          end
        end

        # Converts a TaskPushNotificationConfig to a protobuf TaskPushNotificationConfig
        def task_push_notification_config(config)
          proto_class = get_proto_class("TaskPushNotificationConfig")
          proto_class.new(
            name: "tasks/#{config.task_id}/pushNotificationConfigs/#{config.push_notification_config.id}",
            push_notification_config: push_notification_config(config.push_notification_config)
          )
        end

        # Converts an AgentCard to a protobuf AgentCard
        def agent_card(card)
          proto_class = get_proto_class("AgentCard")
          proto_class.new(
            name: card.name || "",
            description: card.description || "",
            version: card.version || "",
            url: card.url || "",
            preferred_transport: card.preferred_transport || "JSONRPC",
            protocol_version: card.protocol_version || "0.3.0",
            default_input_modes: card.default_input_modes || [],
            default_output_modes: card.default_output_modes || [],
            skills: card.skills&.map { |s| skill(s) } || [],
            capabilities: capabilities(card.capabilities),
            provider: provider(card.provider),
            security: security(card.security),
            security_schemes: security_schemes(card.security_schemes),
            documentation_url: card.documentation_url || "",
            additional_interfaces: card.additional_interfaces&.map { |i| agent_interface(i) } || [],
            supports_authenticated_extended_card: card.supports_authenticated_extended_card || false,
            signatures: card.signatures&.map { |s| agent_card_signature(s) } || []
          )
        end

        # Converts an AgentSkill to a protobuf AgentSkill
        def skill(skill)
          proto_class = get_proto_class("AgentSkill")
          proto_class.new(
            id: skill.id || "",
            name: skill.name || "",
            description: skill.description || "",
            tags: skill.tags || [],
            examples: skill.examples || [],
            input_modes: skill.input_modes || [],
            output_modes: skill.output_modes || []
          )
        end

        # Converts an AgentCapabilities to a protobuf AgentCapabilities
        def capabilities(capabilities)
          proto_class = get_proto_class("AgentCapabilities")
          return proto_class.new if capabilities.nil?

          proto_class.new(
            streaming: capabilities.streaming || false,
            push_notifications: capabilities.push_notifications || false,
            extensions: capabilities.extensions&.map { |e| extension(e) } || []
          )
        end

        # Converts an AgentExtension to a protobuf AgentExtension
        def extension(ext)
          proto_class = get_proto_class("AgentExtension")
          # AgentExtension might be a hash in Ruby
          if ext.is_a?(Hash)
            proto_class.new(
              uri: ext[:uri] || ext["uri"] || "",
              description: ext[:description] || ext["description"] || "",
              params: metadata(ext[:params] || ext["params"]),
              required: ext[:required] || ext["required"] || false
            )
          else
            proto_class.new(
              uri: ext.uri || "",
              description: ext.description || "",
              params: metadata(ext.params),
              required: ext.required || false
            )
          end
        end

        # Converts an AgentProvider to a protobuf AgentProvider
        def provider(provider)
          return nil if provider.nil?

          proto_class = get_proto_class("AgentProvider")
          proto_class.new(
            organization: provider.organization || "",
            url: provider.url || ""
          )
        end

        # Converts security array to protobuf Security array
        def security(security_array)
          return nil if security_array.nil? || security_array.empty?

          proto_class = get_proto_class("Security")
          security_array.map do |sec_hash|
            schemes = {}
            sec_hash.each do |key, value|
              schemes[key] = string_list(value)
            end
            proto_class.new(schemes: schemes)
          end
        end

        # Converts a security_schemes hash to protobuf SecurityScheme hash
        def security_schemes(schemes_hash)
          return nil if schemes_hash.nil? || schemes_hash.empty?

          result = {}
          schemes_hash.each do |key, scheme|
            result[key] = security_scheme(scheme)
          end
          result
        end

        # Converts a SecurityScheme to a protobuf SecurityScheme
        def security_scheme(scheme)
          proto_class = get_proto_class("SecurityScheme")
          case scheme.root
          when Types::APIKeySecurityScheme
            api_key_class = get_proto_class("APIKeySecurityScheme")
            proto_class.new(
              api_key_security_scheme: api_key_class.new(
                description: scheme.root.description || "",
                location: scheme.root.in_ || "",
                name: scheme.root.name || ""
              )
            )
          when Types::HTTPAuthSecurityScheme
            http_auth_class = get_proto_class("HTTPAuthSecurityScheme")
            proto_class.new(
              http_auth_security_scheme: http_auth_class.new(
                description: scheme.root.description || "",
                scheme: scheme.root.scheme || "",
                bearer_format: scheme.root.bearer_format || ""
              )
            )
          when Types::OAuth2SecurityScheme
            oauth2_class = get_proto_class("OAuth2SecurityScheme")
            proto_class.new(
              oauth2_security_scheme: oauth2_class.new(
                description: scheme.root.description || "",
                flows: oauth2_flows(scheme.root.flows)
              )
            )
          when Types::MutualTLSSecurityScheme
            mtls_class = get_proto_class("MutualTlsSecurityScheme")
            proto_class.new(
              mtls_security_scheme: mtls_class.new(
                description: scheme.root.description || ""
              )
            )
          when Types::OpenIdConnectSecurityScheme
            oidc_class = get_proto_class("OpenIdConnectSecurityScheme")
            proto_class.new(
              open_id_connect_security_scheme: oidc_class.new(
                description: scheme.root.description || "",
                open_id_connect_url: scheme.root.open_id_connect_url || ""
              )
            )
          else
            raise ArgumentError, "Unsupported security scheme type: #{scheme.root.class}"
          end
        end

        # Converts OAuthFlows to a protobuf OAuthFlows
        # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def oauth2_flows(flows)
          proto_class = get_proto_class("OAuthFlows")
          # OAuth flows in Ruby are stored as hashes, not objects
          flows_hash = if flows.is_a?(Hash)
                         flows
                       else
                         {
                           authorization_code: flows.authorization_code,
                           client_credentials: flows.client_credentials,
                           implicit: flows.implicit,
                           password: flows.password
                         }
                       end

          if flows_hash[:authorization_code] || flows_hash["authorization_code"]
            flow = flows_hash[:authorization_code] || flows_hash["authorization_code"]
            auth_code_class = get_proto_class("AuthorizationCodeOAuthFlow")
            proto_class.new(
              authorization_code: auth_code_class.new(
                authorization_url: flow[:authorization_url] || flow["authorization_url"] || "",
                refresh_url: flow[:refresh_url] || flow["refresh_url"] || "",
                scopes: flow[:scopes] || flow["scopes"] || {},
                token_url: flow[:token_url] || flow["token_url"] || ""
              )
            )
          elsif flows_hash[:client_credentials] || flows_hash["client_credentials"]
            flow = flows_hash[:client_credentials] || flows_hash["client_credentials"]
            client_creds_class = get_proto_class("ClientCredentialsOAuthFlow")
            proto_class.new(
              client_credentials: client_creds_class.new(
                refresh_url: flow[:refresh_url] || flow["refresh_url"] || "",
                scopes: flow[:scopes] || flow["scopes"] || {},
                token_url: flow[:token_url] || flow["token_url"] || ""
              )
            )
          elsif flows_hash[:implicit] || flows_hash["implicit"]
            flow = flows_hash[:implicit] || flows_hash["implicit"]
            implicit_class = get_proto_class("ImplicitOAuthFlow")
            proto_class.new(
              implicit: implicit_class.new(
                authorization_url: flow[:authorization_url] || flow["authorization_url"] || "",
                refresh_url: flow[:refresh_url] || flow["refresh_url"] || "",
                scopes: flow[:scopes] || flow["scopes"] || {}
              )
            )
          elsif flows_hash[:password] || flows_hash["password"]
            flow = flows_hash[:password] || flows_hash["password"]
            password_class = get_proto_class("PasswordOAuthFlow")
            proto_class.new(
              password: password_class.new(
                refresh_url: flow[:refresh_url] || flow["refresh_url"] || "",
                scopes: flow[:scopes] || flow["scopes"] || {},
                token_url: flow[:token_url] || flow["token_url"] || ""
              )
            )
          else
            raise ArgumentError, "Unknown oauth flow definition"
          end
        end

        # Converts an AgentInterface to a protobuf AgentInterface
        def agent_interface(interface)
          proto_class = get_proto_class("AgentInterface")
          proto_class.new(
            transport: interface.transport || "",
            url: interface.url || ""
          )
        end

        # Converts an AgentCardSignature to a protobuf AgentCardSignature
        def agent_card_signature(signature)
          proto_class = get_proto_class("AgentCardSignature")
          # AgentCardSignature might be a hash in Ruby
          if signature.is_a?(Hash)
            proto_class.new(
              protected: signature[:protected] || signature["protected"] || "",
              signature: signature[:signature] || signature["signature"] || "",
              header: metadata(signature[:header] || signature["header"])
            )
          else
            proto_class.new(
              protected: signature.protected || "",
              signature: signature.signature || "",
              header: metadata(signature.header)
            )
          end
        end

        private

        # Helper to get proto class by name
        def get_proto_class(class_name)
          # This assumes the proto files are generated and available
          # The actual module structure will depend on how the proto files are generated

          A2a::Grpc::A2aPb2.const_get(class_name)
        rescue NameError
          raise LoadError, "A2A protobuf files not found. Please generate proto files from the A2A protocol specification."
        end

        # Converts a value to a Struct value
        def convert_value_to_struct_value(value)
          case value
          when Hash
            metadata(value)
          when Array
            list_value = get_proto_class("ListValue")
            list = list_value.new
            value.each do |item|
              list.values << convert_value_to_struct_value(item)
            end
            list
          when String, Integer, Float, TrueClass, FalseClass, NilClass
            value
          else
            value.to_s
          end
        end

        # Creates a StringList proto
        def string_list(string_array)
          proto_class = get_proto_class("StringList")
          proto_class.new(list: string_array || [])
        end
      end
    end

    # Converts protobuf types to Ruby types
    class FromProto
      class << self
        # Converts a protobuf Message to a Ruby Message
        def message(msg_pb)
          Types::Message.new(
            message_id: msg_pb.message_id,
            parts: msg_pb.content&.map { |p| part(p) } || [],
            context_id: msg_pb.context_id.empty? ? nil : msg_pb.context_id,
            task_id: msg_pb.task_id.empty? ? nil : msg_pb.task_id,
            role: role(msg_pb.role),
            metadata: metadata(msg_pb.metadata),
            extensions: msg_pb.extensions.empty? ? nil : msg_pb.extensions.to_a
          )
        end

        # Converts a protobuf Struct to a hash
        def metadata(struct_pb)
          return {} if struct_pb.nil? || struct_pb.fields.nil? || struct_pb.fields.empty?

          result = {}
          struct_pb.fields.each do |key, value|
            result[key] = convert_struct_value_to_ruby(value)
          end
          result
        end

        # Converts a protobuf Part to a Ruby Part
        def part(part_pb)
          # Ruby protobuf doesn't use has_* methods, check field presence differently
          if part_pb.respond_to?(:text) && part_pb.text && !part_pb.text.to_s.empty?
            Types::Part.new(
              root: Types::TextPart.new(
                text: part_pb.text,
                metadata: metadata(part_pb.metadata)
              )
            )
          elsif part_pb.respond_to?(:file) && part_pb.file
            Types::Part.new(
              root: Types::FilePart.new(
                file: file(part_pb.file),
                metadata: metadata(part_pb.metadata)
              )
            )
          elsif part_pb.respond_to?(:data) && part_pb.data
            Types::Part.new(
              root: Types::DataPart.new(
                data: data(part_pb.data),
                metadata: metadata(part_pb.metadata)
              )
            )
          else
            raise ArgumentError, "Unsupported part type: #{part_pb}"
          end
        end

        # Converts a protobuf DataPart to a hash
        def data(data_pb)
          metadata(data_pb.data)
        end

        # Converts a protobuf FilePart to a FileWithUri or FileWithBytes
        def file(file_pb)
          common_args = {
            mime_type: file_pb.mime_type && !file_pb.mime_type.to_s.empty? ? file_pb.mime_type : nil,
            name: file_pb.name && !file_pb.name.to_s.empty? ? file_pb.name : nil
          }
          if file_pb.respond_to?(:file_with_uri) && file_pb.file_with_uri && !file_pb.file_with_uri.to_s.empty?
            Types::FileWithUri.new(uri: file_pb.file_with_uri, **common_args)
          elsif file_pb.respond_to?(:file_with_bytes) && file_pb.file_with_bytes
            Types::FileWithBytes.new(bytes: file_pb.file_with_bytes.decode("utf-8"), **common_args)
          else
            raise ArgumentError, "FilePart must have either file_with_uri or file_with_bytes"
          end
        end

        # Converts a protobuf Task to a Ruby Task
        def task(task_pb)
          Types::Task.new(
            id: task_pb.id,
            context_id: task_pb.context_id,
            status: task_status(task_pb.status),
            artifacts: task_pb.artifacts&.map { |a| artifact(a) } || [],
            history: task_pb.history&.map { |h| message(h) } || [],
            metadata: metadata(task_pb.metadata)
          )
        end

        # Converts a protobuf TaskStatus to a Ruby TaskStatus
        def task_status(status_pb)
          Types::TaskStatus.new(
            state: task_state(status_pb.state),
            message: message(status_pb.update)
          )
        end

        # Converts a protobuf TaskState enum to a Ruby TaskState string
        def task_state(state_pb)
          proto_class = get_proto_class("TaskState")
          case state_pb
          when proto_class::TASK_STATE_SUBMITTED
            Types::TaskState::SUBMITTED
          when proto_class::TASK_STATE_WORKING
            Types::TaskState::WORKING
          when proto_class::TASK_STATE_COMPLETED
            Types::TaskState::COMPLETED
          when proto_class::TASK_STATE_CANCELLED
            Types::TaskState::CANCELED
          when proto_class::TASK_STATE_FAILED
            Types::TaskState::FAILED
          when proto_class::TASK_STATE_INPUT_REQUIRED
            Types::TaskState::INPUT_REQUIRED
          when proto_class::TASK_STATE_AUTH_REQUIRED
            Types::TaskState::AUTH_REQUIRED
          else
            Types::TaskState::UNKNOWN
          end
        end

        # Converts a protobuf Artifact to a Ruby Artifact
        def artifact(artifact_pb)
          Types::Artifact.new(
            artifact_id: artifact_pb.artifact_id,
            description: artifact_pb.description,
            metadata: metadata(artifact_pb.metadata),
            name: artifact_pb.name,
            parts: artifact_pb.parts&.map { |p| part(p) } || [],
            extensions: artifact_pb.extensions.empty? ? nil : artifact_pb.extensions.to_a
          )
        end

        # Converts a protobuf Role enum to a Ruby Role string
        def role(role_pb)
          proto_class = get_proto_class("Role")
          case role_pb
          when proto_class::ROLE_USER
            Types::Role::USER
          when proto_class::ROLE_AGENT
            Types::Role::AGENT
          else
            Types::Role::AGENT
          end
        end

        # Converts a protobuf SendMessageResponse to a Task or Message
        def task_or_message(response_pb)
          if response_pb.respond_to?(:msg) && response_pb.msg && !response_pb.msg.to_s.empty?
            message(response_pb.msg)
          elsif response_pb.respond_to?(:task) && response_pb.task
            task(response_pb.task)
          else
            raise ArgumentError, "SendMessageResponse must have either msg or task"
          end
        end

        # Converts a protobuf StreamResponse to a Ruby type
        def stream_response(response_pb)
          if response_pb.respond_to?(:msg) && response_pb.msg && !response_pb.msg.to_s.empty?
            message(response_pb.msg)
          elsif response_pb.respond_to?(:task) && response_pb.task
            task(response_pb.task)
          elsif response_pb.respond_to?(:status_update) && response_pb.status_update
            task_status_update_event(response_pb.status_update)
          elsif response_pb.respond_to?(:artifact_update) && response_pb.artifact_update
            task_artifact_update_event(response_pb.artifact_update)
          else
            raise ArgumentError, "Unsupported StreamResponse type"
          end
        end

        # Converts a protobuf TaskStatusUpdateEvent to a Ruby TaskStatusUpdateEvent
        def task_status_update_event(event_pb)
          Types::TaskStatusUpdateEvent.new(
            task_id: event_pb.task_id,
            context_id: event_pb.context_id,
            status: task_status(event_pb.status),
            metadata: metadata(event_pb.metadata),
            final: event_pb.final
          )
        end

        # Converts a protobuf TaskArtifactUpdateEvent to a Ruby TaskArtifactUpdateEvent
        def task_artifact_update_event(event_pb)
          Types::TaskArtifactUpdateEvent.new(
            task_id: event_pb.task_id,
            context_id: event_pb.context_id,
            artifact: artifact(event_pb.artifact),
            metadata: metadata(event_pb.metadata),
            append: event_pb.append,
            last_chunk: event_pb.last_chunk
          )
        end

        # Converts a protobuf TaskPushNotificationConfig to a Ruby TaskPushNotificationConfig
        def task_push_notification_config(config_pb)
          match = TASK_PUSH_CONFIG_NAME_MATCH.match(config_pb.name)
          raise ArgumentError, "Bad TaskPushNotificationConfig resource name #{config_pb.name}" unless match

          Types::TaskPushNotificationConfig.new(
            task_id: match[1],
            push_notification_config: push_notification_config(config_pb.push_notification_config)
          )
        end

        # Converts a protobuf PushNotificationConfig to a Ruby PushNotificationConfig
        def push_notification_config(config_pb)
          Types::PushNotificationConfig.new(
            id: config_pb.id,
            url: config_pb.url,
            token: config_pb.token,
            authentication: config_pb.respond_to?(:authentication) && config_pb.authentication ? authentication_info(config_pb.authentication) : nil
          )
        end

        # Converts a protobuf AuthenticationInfo to a Ruby PushNotificationAuthenticationInfo
        def authentication_info(info_pb)
          Types::PushNotificationAuthenticationInfo.new(
            schemes: info_pb.schemes.to_a,
            credentials: info_pb.credentials || {}
          )
        end

        # Converts a protobuf AgentCard to a Ruby AgentCard
        def agent_card(card_pb)
          Types::AgentCard.new(
            name: card_pb.name,
            description: card_pb.description,
            version: card_pb.version,
            url: card_pb.url,
            preferred_transport: card_pb.preferred_transport,
            protocol_version: card_pb.protocol_version,
            default_input_modes: card_pb.default_input_modes.to_a,
            default_output_modes: card_pb.default_output_modes.to_a,
            skills: card_pb.skills&.map { |s| skill(s) } || [],
            capabilities: capabilities(card_pb.capabilities),
            provider: provider(card_pb.provider),
            security: security(card_pb.security.to_a),
            security_schemes: security_schemes(card_pb.security_schemes.to_h),
            documentation_url: card_pb.documentation_url,
            additional_interfaces: card_pb.additional_interfaces&.map { |i| agent_interface(i) } || [],
            supports_authenticated_extended_card: card_pb.supports_authenticated_extended_card,
            signatures: card_pb.signatures&.map { |s| agent_card_signature(s) } || []
          )
        end

        # Converts a protobuf AgentSkill to a Ruby AgentSkill
        def skill(skill_pb)
          Types::AgentSkill.new(
            id: skill_pb.id,
            name: skill_pb.name,
            description: skill_pb.description,
            tags: skill_pb.tags.to_a,
            examples: skill_pb.examples.to_a,
            input_modes: skill_pb.input_modes.to_a,
            output_modes: skill_pb.output_modes.to_a
          )
        end

        # Converts a protobuf AgentCapabilities to a Ruby AgentCapabilities
        def capabilities(capabilities_pb)
          return Types::AgentCapabilities.new if capabilities_pb.nil?

          Types::AgentCapabilities.new(
            streaming: capabilities_pb.streaming,
            push_notifications: capabilities_pb.push_notifications,
            extensions: capabilities_pb.extensions&.map { |e| agent_extension(e) } || []
          )
        end

        # Converts a protobuf AgentExtension to a Ruby hash (AgentExtension not a class in Ruby)
        def agent_extension(ext_pb)
          {
            uri: ext_pb.uri,
            description: ext_pb.description,
            params: metadata(ext_pb.params),
            required: ext_pb.required
          }
        end

        # Converts a protobuf AgentProvider to a Ruby AgentProvider
        def provider(provider_pb)
          return nil if provider_pb.nil?

          Types::AgentProvider.new(
            organization: provider_pb.organization,
            url: provider_pb.url
          )
        end

        # Converts a protobuf Security array to a Ruby security array
        def security(security_array)
          return nil if security_array.nil? || security_array.empty?

          security_array.map do |sec_pb|
            result = {}
            sec_pb.schemes.each do |key, string_list_pb|
              result[key] = string_list_pb.list.to_a
            end
            result
          end
        end

        # Converts a protobuf SecurityScheme hash to a Ruby SecurityScheme hash
        def security_schemes(schemes_hash)
          return nil if schemes_hash.nil? || schemes_hash.empty?

          result = {}
          schemes_hash.each do |key, scheme_pb|
            result[key] = security_scheme(scheme_pb)
          end
          result
        end

        # Converts a protobuf SecurityScheme to a Ruby SecurityScheme
        def security_scheme(scheme_pb)
          if scheme_pb.respond_to?(:api_key_security_scheme) && scheme_pb.api_key_security_scheme
            api_key = scheme_pb.api_key_security_scheme
            Types::SecurityScheme.new(
              root: Types::APIKeySecurityScheme.new(
                description: api_key.description,
                name: api_key.name,
                in_: api_key.location
              )
            )
          elsif scheme_pb.respond_to?(:http_auth_security_scheme) && scheme_pb.http_auth_security_scheme
            http_auth = scheme_pb.http_auth_security_scheme
            Types::SecurityScheme.new(
              root: Types::HTTPAuthSecurityScheme.new(
                description: http_auth.description,
                scheme: http_auth.scheme,
                bearer_format: http_auth.bearer_format
              )
            )
          elsif scheme_pb.respond_to?(:oauth2_security_scheme) && scheme_pb.oauth2_security_scheme
            oauth2 = scheme_pb.oauth2_security_scheme
            Types::SecurityScheme.new(
              root: Types::OAuth2SecurityScheme.new(
                description: oauth2.description,
                flows: oauth2_flows(oauth2.flows)
              )
            )
          elsif scheme_pb.respond_to?(:mtls_security_scheme) && scheme_pb.mtls_security_scheme
            mtls = scheme_pb.mtls_security_scheme
            Types::SecurityScheme.new(
              root: Types::MutualTLSSecurityScheme.new(
                description: mtls.description
              )
            )
          elsif scheme_pb.respond_to?(:open_id_connect_security_scheme) && scheme_pb.open_id_connect_security_scheme
            oidc = scheme_pb.open_id_connect_security_scheme
            Types::SecurityScheme.new(
              root: Types::OpenIdConnectSecurityScheme.new(
                description: oidc.description,
                open_id_connect_url: oidc.open_id_connect_url
              )
            )
          else
            raise ArgumentError, "Unsupported security scheme type"
          end
        end

        # Converts a protobuf OAuthFlows to a Ruby OAuthFlows
        def oauth2_flows(flows_pb)
          # OAuth flow classes don't exist in Ruby, so we return hashes
          if flows_pb.respond_to?(:authorization_code) && flows_pb.authorization_code
            auth_code = flows_pb.authorization_code
            Types::OAuthFlows.new(
              authorization_code: {
                authorization_url: auth_code.authorization_url,
                refresh_url: auth_code.refresh_url,
                scopes: auth_code.scopes.respond_to?(:to_h) ? auth_code.scopes.to_h : auth_code.scopes,
                token_url: auth_code.token_url
              }
            )
          elsif flows_pb.respond_to?(:client_credentials) && flows_pb.client_credentials
            client_creds = flows_pb.client_credentials
            Types::OAuthFlows.new(
              client_credentials: {
                refresh_url: client_creds.refresh_url,
                scopes: client_creds.scopes.respond_to?(:to_h) ? client_creds.scopes.to_h : client_creds.scopes,
                token_url: client_creds.token_url
              }
            )
          elsif flows_pb.respond_to?(:implicit) && flows_pb.implicit
            implicit = flows_pb.implicit
            Types::OAuthFlows.new(
              implicit: {
                authorization_url: implicit.authorization_url,
                refresh_url: implicit.refresh_url,
                scopes: implicit.scopes.respond_to?(:to_h) ? implicit.scopes.to_h : implicit.scopes
              }
            )
          elsif flows_pb.respond_to?(:password) && flows_pb.password
            password = flows_pb.password
            Types::OAuthFlows.new(
              password: {
                refresh_url: password.refresh_url,
                scopes: password.scopes.respond_to?(:to_h) ? password.scopes.to_h : password.scopes,
                token_url: password.token_url
              }
            )
          else
            raise ArgumentError, "Unknown oauth flow definition"
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        # Converts a protobuf AgentInterface to a Ruby AgentInterface
        def agent_interface(interface_pb)
          Types::AgentInterface.new(
            transport: interface_pb.transport,
            url: interface_pb.url
          )
        end

        # Converts a protobuf AgentCardSignature to a Ruby hash (AgentCardSignature not a class in Ruby)
        def agent_card_signature(signature_pb)
          {
            protected: signature_pb.protected,
            signature: signature_pb.signature,
            header: metadata(signature_pb.header)
          }
        end

        # Converts a protobuf GetTaskRequest to TaskQueryParams
        def task_query_params(request_pb)
          match = TASK_NAME_MATCH.match(request_pb.name)
          raise ArgumentError, "No task for #{request_pb.name}" unless match

          Types::TaskQueryParams.new(
            id: match[1],
            history_length: request_pb.history_length.zero? ? nil : request_pb.history_length,
            metadata: nil
          )
        end

        # Converts a protobuf CancelTaskRequest or TaskSubscriptionRequest to TaskIdParams
        def task_id_params(request_pb)
          match = TASK_NAME_MATCH.match(request_pb.name)
          raise ArgumentError, "No task for #{request_pb.name}" unless match

          Types::TaskIdParams.new(id: match[1])
        end

        private

        # Helper to get proto class by name
        def get_proto_class(class_name)
          A2a::Grpc::A2aPb2.const_get(class_name)
        rescue NameError
          raise LoadError, "A2A protobuf files not found. Please generate proto files from the A2A protocol specification."
        end

        # Converts a Struct value to a Ruby value
        def convert_struct_value_to_ruby(value)
          case value.kind
          when :null_value
            nil
          when :number_value
            value.number_value
          when :string_value
            value.string_value
          when :bool_value
            value.bool_value
          when :struct_value
            metadata(value.struct_value)
          when :list_value
            value.list_value.values.map { |v| convert_struct_value_to_ruby(v) }
          else
            value.to_s
          end
        end
      end
    end
  end
end
