# frozen_string_literal: true

module A2a
  module Types
    # Defines parameters for querying a task, with an option to limit history length.
    class TaskQueryParams < BaseModel
      attr_accessor :id, :history_length, :metadata

      def initialize(attributes = {})
        super
        @id = attributes[:id] || attributes["id"]
        @history_length = attributes[:history_length] || attributes["historyLength"]
        @metadata = attributes[:metadata] || attributes["metadata"]
      end
    end

    # Defines parameters containing a task ID, used for simple task operations.
    class TaskIdParams < BaseModel
      attr_accessor :id, :metadata

      def initialize(attributes = {})
        super
        @id = attributes[:id] || attributes["id"]
        @metadata = attributes[:metadata] || attributes["metadata"]
      end
    end

    # Defines the configuration for sending a message.
    class MessageSendConfiguration < BaseModel
      attr_accessor :accepted_output_modes, :blocking, :push_notification_config

      def initialize(attributes = {})
        super
        @accepted_output_modes = attributes[:accepted_output_modes] || attributes["acceptedOutputModes"] || []
        @blocking = attributes[:blocking] != false # Default to true unless explicitly false
        @blocking = attributes["blocking"] != false if attributes.key?("blocking")
        push_config_data = attributes[:push_notification_config] || attributes["pushNotificationConfig"]
        @push_notification_config = if push_config_data
                                      push_config_data.is_a?(PushNotificationConfig) ? push_config_data : PushNotificationConfig.new(push_config_data)
                                    end
      end
    end

    # Defines the parameters for a request to send a message to an agent.
    class MessageSendParams < BaseModel
      attr_accessor :message, :configuration, :metadata

      def initialize(attributes = {})
        super
        message_data = attributes[:message] || attributes["message"]
        @message = if message_data
                     message_data.is_a?(Message) ? message_data : Message.new(message_data)
                   end
        config_data = attributes[:configuration] || attributes["configuration"]
        @configuration = if config_data
                           config_data.is_a?(MessageSendConfiguration) ? config_data : MessageSendConfiguration.new(config_data)
                         end
        @metadata = attributes[:metadata] || attributes["metadata"]
      end
    end

    # Defines parameters for getting push notification configuration.
    class GetTaskPushNotificationConfigParams < BaseModel
      attr_accessor :id, :push_notification_config_id, :metadata

      def initialize(attributes = {})
        super
        @id = attributes[:id] || attributes["id"]
        @push_notification_config_id = attributes[:push_notification_config_id] || attributes["pushNotificationConfigId"]
        @metadata = attributes[:metadata] || attributes["metadata"]
      end
    end

    # A container associating a push notification configuration with a specific task.
    class TaskPushNotificationConfig < BaseModel
      attr_accessor :task_id, :push_notification_config

      def initialize(attributes = {})
        super
        @task_id = attributes[:task_id] || attributes["taskId"]
        push_config_data = attributes[:push_notification_config] || attributes["pushNotificationConfig"]
        @push_notification_config = if push_config_data
                                      push_config_data.is_a?(PushNotificationConfig) ? push_config_data : PushNotificationConfig.new(push_config_data)
                                    end
      end
    end

    # Defines the configuration for setting up push notifications for task updates.
    class PushNotificationConfig < BaseModel
      attr_accessor :id, :url, :token, :authentication

      def initialize(attributes = {})
        super
        @id = attributes[:id] || attributes["id"]
        @url = attributes[:url] || attributes["url"]
        @token = attributes[:token] || attributes["token"]
        auth_data = attributes[:authentication] || attributes["authentication"]
        @authentication = if auth_data
                            auth_data.is_a?(PushNotificationAuthenticationInfo) ? auth_data : PushNotificationAuthenticationInfo.new(auth_data)
                          end
      end
    end

    # Defines authentication details for a push notification endpoint.
    class PushNotificationAuthenticationInfo < BaseModel
      attr_accessor :schemes, :credentials

      def initialize(attributes = {})
        super
        @schemes = attributes[:schemes] || attributes["schemes"] || []
        @credentials = attributes[:credentials] || attributes["credentials"]
      end
    end
  end
end
