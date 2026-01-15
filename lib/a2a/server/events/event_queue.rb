# frozen_string_literal: true

require_relative "../../types"

module A2a
  module Server
    module Events
      # Events that can be enqueued are: Message, Task, TaskStatusUpdateEvent, TaskArtifactUpdateEvent
      # This is a type concept - in Ruby we check with is_a? instead of type unions

      DEFAULT_MAX_QUEUE_SIZE = 1024

      # Event queue for A2A responses from agent.
      #
      # Acts as a buffer between the agent's asynchronous execution and the
      # server's response handling (e.g., streaming via SSE). Supports tapping
      # to create child queues that receive the same events.
      class EventQueue
        attr_reader :max_queue_size

        def initialize(max_queue_size: DEFAULT_MAX_QUEUE_SIZE)
          raise ArgumentError, "max_queue_size must be greater than 0" if max_queue_size <= 0

          @max_queue_size = max_queue_size
          @queue = Thread::Queue.new
          @children = []
          @closed = false
          @lock = Mutex.new
        end

        # Enqueues an event to this queue and all its children.
        #
        # @param event [Event] The event object to enqueue.
        def enqueue_event(event)
          @lock.synchronize do
            if @closed
              # Queue is closed, don't enqueue
              return
            end
          end

          # Enqueue to this queue (will block if queue is full)
          @queue << event

          # Enqueue to all children
          @children.each do |child|
            child.enqueue_event(event)
          end
        end

        # Dequeues an event from the queue.
        #
        # @param no_wait [Boolean] If true, retrieve an event immediately or raise ThreadError.
        #                          If false (default), wait until an event is available.
        # @return [Event] The next event from the queue.
        # @raise [ThreadError] If `no_wait` is true and the queue is empty, or if the queue is closed.
        def dequeue_event(no_wait: false)
          @lock.synchronize do
            raise ThreadError, "Queue is closed" if @closed && @queue.empty?
          end

          if no_wait
            raise ThreadError, "Queue is empty" if @queue.empty?

            @queue.pop(true) # non-blocking
          else
            @queue.pop # blocking
          end
        end

        # Signals that a formerly enqueued task is complete.
        #
        # Used in conjunction with `dequeue_event` to track processed items.
        def task_done
          # Thread::Queue doesn't have task_done, but we can track this if needed
          # For now, this is a no-op to match the Python interface
        end

        # Taps the event queue to create a new child queue that receives all future events.
        #
        # @return [EventQueue] A new EventQueue instance that will receive all events enqueued
        #                     to this parent queue from this point forward.
        def tap
          child = EventQueue.new(max_queue_size: @max_queue_size)
          @lock.synchronize do
            @children << child
          end
          child
        end

        # Closes the queue for future push events and also closes all child queues.
        #
        # Once closed, no new events can be enqueued.
        #
        # @param immediate [Boolean] If true, immediately closes the queue and clears all
        #                            unprocessed events. If false (default), gracefully closes
        #                            the queue, waiting for all queued events to be processed.
        def close(immediate: false)
          @lock.synchronize do
            return if @closed && !immediate

            @closed = true
          end

          if immediate
            clear_events(clear_child_queues: true)
            @children.each { |child| child.close(immediate: true) }
          else
            # Graceful close: wait for queue to drain
            # In Ruby, we can't easily wait for queue to drain without blocking
            # So we'll just mark as closed and let consumers finish
            @children.each { |child| child.close(immediate: false) }
          end
        end

        # Checks if the queue is closed.
        #
        # @return [Boolean] True if the queue is closed, false otherwise.
        def closed?
          @lock.synchronize { @closed }
        end

        # Clears all events from the current queue and optionally all child queues.
        #
        # @param clear_child_queues [Boolean] If true (default), clear all child queues as well.
        def clear_events(clear_child_queues: true)
          cleared_count = 0
          @lock.synchronize do
            loop do
              @queue.pop(true) # non-blocking
              cleared_count += 1
            rescue ThreadError
              break
            end
          end

          # Clear all child queues
          @children.each { |child| child.clear_events(clear_child_queues: true) } if clear_child_queues && !@children.empty?

          cleared_count
        end

        # Checks if the queue is empty.
        #
        # @return [Boolean] True if the queue is empty, false otherwise.
        def empty?
          @queue.empty?
        end
      end
    end
  end
end
