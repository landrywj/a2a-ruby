# frozen_string_literal: true

module A2a
  module Rails
    # ActionCable channel for streaming A2A events to clients.
    #
    # This channel allows clients to subscribe to real-time updates for a specific task.
    # Events are broadcast from the server when they occur during agent execution.
    #
    # Usage on client:
    #   const channel = consumer.subscriptions.create(
    #     { channel: "A2a::Rails::StreamingChannel", task_id: "task-123" },
    #     {
    #       received(data) { console.log("Event:", data); }
    #     }
    #   );
    #
    # Usage on server:
    #   A2a::Rails::StreamingChannel.broadcast_event("task-123", event_data)
    class StreamingChannel < (defined?(ActionCable::Channel::Base) ? ActionCable::Channel::Base : Object)
      if defined?(ActionCable::Channel::Base)
        def subscribed
          task_id = params[:task_id]
          return reject unless task_id

          stream_from "a2a_task_#{task_id}"
        end

        def unsubscribed
          # Cleanup if needed
        end
      end

      # Broadcasts an event to all subscribers of a task.
      #
      # @param task_id [String] The task ID
      # @param event [Object] The event to broadcast
      def self.broadcast_event(task_id, event)
        if defined?(ActionCable::Server::Broadcasting)
          ActionCable.server.broadcast("a2a_task_#{task_id}", event: serialize_event(event))
        end
      end

      private

      def self.serialize_event(event)
        # Serialize the event to a hash for JSON transmission
        # In a real implementation, this would use the type's serialization
        if event.respond_to?(:to_h)
          event.to_h
        elsif event.respond_to?(:to_json)
          JSON.parse(event.to_json)
        else
          { type: event.class.name, data: event.inspect }
        end
      end
    end
  end
end
