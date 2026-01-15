# frozen_string_literal: true

require_relative "../events/event_consumer"
require_relative "../../types"

module A2a
  module Server
    module Tasks
      # ResultAggregator is used to process the event streams from an AgentExecutor.
      #
      # There are three main ways to use the ResultAggregator:
      # 1) As part of a processing pipe. consume_and_emit will construct the updated
      #    task as the events arrive, and re-emit those events for another consumer
      # 2) As part of a blocking call. consume_all will process the entire stream and
      #    return the final Task or Message object
      # 3) As part of a push solution where the latest Task is emitted after processing an event.
      #    consume_and_emit_task will consume the Event stream, process the events to the current
      #    Task object and emit that Task object.
      class ResultAggregator
        attr_reader :task_manager

        def initialize(task_manager)
          @task_manager = task_manager
          @message = nil
        end

        # Returns the current aggregated result (Task or Message).
        #
        # This is the latest state processed from the event stream.
        #
        # @return [Types::Task, Types::Message, nil] The current Task object managed by the
        #                                             TaskManager, or the final Message if one
        #                                             was received, or nil if no result has been produced yet.
        def current_result
          return @message if @message

          @task_manager.get_task
        end

        # Processes the event stream from the consumer, updates the task state, and re-emits the same events.
        #
        # Useful for streaming scenarios where the server needs to observe and
        # process events (e.g., save task state, send push notifications) while
        # forwarding them to the client.
        #
        # @param consumer [Events::EventConsumer] The EventConsumer to read events from.
        # @yield [Object] Event objects consumed from the EventConsumer.
        # @return [Enumerator] An enumerator that yields Event objects
        def consume_and_emit(consumer)
          return enum_for(:consume_and_emit, consumer) unless block_given?

          consumer.consume_all do |event|
            @task_manager.process(event)
            yield event
          end
        end

        # Processes the entire event stream from the consumer and returns the final result.
        #
        # Blocks until the event stream ends (queue is closed after final event or exception).
        #
        # @param consumer [Events::EventConsumer] The EventConsumer to read events from.
        # @return [Types::Task, Types::Message, nil] The final Task object or Message object after
        #                                            the stream is exhausted. Returns nil if the stream
        #                                            ends without producing a final result.
        # @raise [Exception] If the EventConsumer raises an exception during consumption.
        def consume_all(consumer)
          consumer.consume_all do |event|
            if event.is_a?(Types::Message)
              @message = event
              return event
            end
            @task_manager.process(event)
          end

          @task_manager.get_task
        end

        # Processes the event stream until completion or an interruptable state is encountered.
        #
        # If `blocking` is false, it returns after the first event that creates a Task or Message.
        # If `blocking` is true, it waits for completion unless an `auth_required`
        # state is encountered, which is always an interruption.
        # If interrupted, consumption continues in a background task.
        #
        # @param consumer [Events::EventConsumer] The EventConsumer to read events from.
        # @param blocking [Boolean] If false, the method returns as soon as a task/message
        #                          is available. If true, it waits for a terminal state.
        # @param event_callback [Proc, nil] Optional callback function to be called after each event
        #                                   is processed in the background continuation.
        #                                   Mainly used for push notifications currently.
        # @return [Array] A tuple containing:
        #                 - The current aggregated result (Task or Message) at the point of completion or interruption.
        #                 - A boolean indicating whether the consumption was interrupted (true) or completed naturally (false).
        # @raise [Exception] If the EventConsumer raises an exception during consumption.
        def consume_and_break_on_interrupt(consumer, blocking: true, event_callback: nil)
          event_stream = consumer.consume_all
          interrupted = false

          event_stream.each do |event|
            if event.is_a?(Types::Message)
              @message = event
              return [event, false]
            end

            @task_manager.process(event)

            is_auth_required = (event.is_a?(Types::Task) || event.is_a?(Types::TaskStatusUpdateEvent)) &&
                               event.status.state == Types::TaskState::AUTH_REQUIRED

            # Always interrupt on auth_required, as it needs external action.
            # For non-blocking calls, interrupt as soon as a task is available.
            should_interrupt = is_auth_required || !blocking

            next unless should_interrupt

            # Continue consuming the rest of the events in the background.
            Thread.new do
              _continue_consuming(event_stream, event_callback)
            end
            interrupted = true
            break
          end

          [@task_manager.get_task, interrupted]
        end

        private

        def _continue_consuming(event_stream, event_callback)
          event_stream.each do |event|
            @task_manager.process(event)
            event_callback&.call
          end
        end
      end
    end
  end
end
