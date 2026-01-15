# frozen_string_literal: true

require "timeout"
require_relative "event_queue"
require_relative "../../server/errors"
require_relative "../../types"

module A2a
  module Server
    module Events
      # Consumer to read events from the agent event queue.
      class EventConsumer
        attr_reader :queue

        def initialize(queue)
          @queue = queue
          @timeout = 0.5
          @exception = nil
        end

        # Consume one event from the agent event queue non-blocking.
        #
        # @return [Event] The next event from the queue.
        # @raise [ServerError] If the queue is empty when attempting to dequeue immediately.
        def consume_one
          begin
            event = @queue.dequeue_event(no_wait: true)
          rescue ThreadError => e
            raise ServerError.new(
              error: Types::JSONRPCError.new(code: -32_603, message: "Agent did not return any response")
            ), e.message
          end

          @queue.task_done
          event
        end

        # Consume all the generated streaming events from the agent.
        #
        # This method yields events as they become available from the queue
        # until a final event is received or the queue is closed.
        #
        # @yield [Event] Events dequeued from the queue.
        # @return [Enumerator] An enumerator that yields events
        def consume_all
          return enum_for(:consume_all) unless block_given?

          loop do
            raise @exception if @exception

            begin
              # Use a timeout when waiting for an event from the queue.
              # This allows the loop to check if @exception has been set.
              event = Timeout.timeout(@timeout) { @queue.dequeue_event(no_wait: false) }

              @queue.task_done

              is_final_event = final_event?(event)

              # If it's a final event, close the queue and yield the event
              if is_final_event
                @queue.close(immediate: true)
                yield event
                break
              end

              yield event
            rescue Timeout::Error
              # Continue polling until there is a final event
              next
            rescue ThreadError
              # Queue is closed or empty
              break if @queue.closed?

              # If queue is empty but not closed, continue waiting
              next
            rescue StandardError => e
              # Store exception to be raised on next iteration
              @exception = e
              next
            end
          end
        end

        # Callback to handle exceptions from the agent's execution.
        #
        # If the agent's execution raises an exception, this callback is
        # invoked, and the exception is stored to be re-raised by the consumer loop.
        #
        # @param exception [Exception] The exception from the agent execution.
        def agent_task_callback(exception)
          @exception = exception if exception
        end

        private

        def final_event?(event)
          return true if event.is_a?(Types::Message)
          return true if event.is_a?(Types::TaskStatusUpdateEvent) && event.final

          if event.is_a?(Types::Task)
            terminal_states = [
              Types::TaskState::COMPLETED,
              Types::TaskState::CANCELED,
              Types::TaskState::FAILED,
              Types::TaskState::REJECTED,
              Types::TaskState::UNKNOWN,
              Types::TaskState::INPUT_REQUIRED
            ]
            return true if terminal_states.include?(event.status.state)
          end

          false
        end
      end
    end
  end
end
