# frozen_string_literal: true

require_relative "request_handler"
require_relative "../../server/errors"
require_relative "../../types"
require_relative "../../utils/task"
require_relative "../events/event_consumer"
require_relative "../events/in_memory_queue_manager"
require_relative "../tasks/result_aggregator"
require "securerandom"
require "ostruct"

module A2a
  module Server
    module RequestHandlers
      # Default request handler for all incoming requests.
      #
      # This handler provides default implementations for all A2A JSON-RPC methods,
      # coordinating between the AgentExecutor, TaskStore, QueueManager,
      # and optional PushNotifier.
      #
      # Note: This is a basic implementation. Full implementation requires:
      # - AgentExecutor: Executes agent logic
      # - TaskStore: Manages task persistence
      # - QueueManager: Manages event queues
      # - PushNotificationConfigStore: Manages push notification configurations
      # - PushNotificationSender: Sends push notifications
      # - RequestContextBuilder: Builds request contexts
      # - TaskManager: Manages task lifecycle during execution
      class DefaultRequestHandler < RequestHandler
        TERMINAL_TASK_STATES = [
          Types::TaskState::COMPLETED,
          Types::TaskState::CANCELED,
          Types::TaskState::FAILED,
          Types::TaskState::REJECTED
        ].freeze

        attr_reader :agent_executor, :task_store, :queue_manager, :push_config_store, :push_sender, :request_context_builder

        def initialize(
          agent_executor:,
          task_store:,
          queue_manager: nil,
          push_config_store: nil,
          push_sender: nil,
          request_context_builder: nil,
          task_manager_class: nil
        )
          @agent_executor = agent_executor
          @task_store = task_store
          @queue_manager = queue_manager || Events::InMemoryQueueManager.new
          @push_config_store = push_config_store
          @push_sender = push_sender
          @request_context_builder = request_context_builder
          @task_manager_class = task_manager_class
          @running_agents = {}
          @running_agents_lock = Mutex.new
          @background_tasks = []
        end

        # Default handler for 'tasks/get'.
        #
        # @param params [Types::TaskQueryParams] Parameters specifying the task ID and optionally history length.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::Task, nil] The Task object if found, otherwise nil.
        def on_get_task(params, context = nil)
          task = @task_store.get(params.id, context)
          raise ServerError, Types::JSONRPCError.new(code: -32_001, message: "Task not found") unless task

          # Apply historyLength parameter if specified
          Utils::Task.apply_history_length(task, params.history_length)
        end

        # Default handler for 'tasks/cancel'.
        #
        # Attempts to cancel the task managed by the AgentExecutor.
        #
        # @param params [Types::TaskIdParams] Parameters specifying the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::Task, nil] The Task object with its status updated to canceled, or nil if the task was not found.
        def on_cancel_task(params, context = nil)
          task = @task_store.get(params.id, context)
          raise ServerError, Types::JSONRPCError.new(code: -32_001, message: "Task not found") unless task

          # Check if task is in a non-cancelable state
          if TERMINAL_TASK_STATES.include?(task.status.state)
            raise ServerError, Types::JSONRPCError.new(
              code: -32_002,
              message: "Task cannot be canceled - current state: #{task.status.state}"
            )
          end

          # Cancel the task
          # Note: Full implementation would use AgentExecutor.cancel and QueueManager
          # For now, we'll mark it as canceled directly
          task.status.state = Types::TaskState::CANCELED
          @task_store.save(task, context) if @task_store.respond_to?(:save)

          task
        end

        # Default handler for 'message/send' (non-streaming).
        #
        # @param params [Types::MessageSendParams] Parameters including the message and configuration.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::Task, Types::Message] The final Task object or a final Message object.
        def on_message_send(params, context = nil)
          raise NotImplementedError, "on_message_send requires AgentExecutor implementation"
        end

        # Default handler for 'message/stream' (streaming).
        #
        # Starts the agent execution and yields events as they are produced by the agent.
        #
        # @param params [Types::MessageSendParams] Parameters including the message and configuration.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @yield [Object] Event objects from the agent's execution
        # @return [Enumerator] An enumerator that yields Event objects
        def on_message_send_stream(params, context = nil)
          return enum_for(:on_message_send_stream, params, context) unless block_given?

          task_manager, task_id, queue, result_aggregator, producer_thread = _setup_message_execution(params, context)

          consumer = Events::EventConsumer.new(queue)

          # Set up callback for producer thread exceptions
          producer_thread[:exception_handler] = lambda do |exception|
            consumer.agent_task_callback(exception)
          end

          begin
            result_aggregator.consume_and_emit(consumer) do |event|
              _validate_task_id_match(task_id, event.id) if event.is_a?(Types::Task)

              _send_push_notification_if_needed(task_id, result_aggregator)

              # Broadcast to ActionCable if available
              _broadcast_event(task_id, event) if defined?(A2a::Rails::StreamingChannel)

              yield event
            end
          rescue StandardError
            # Client disconnected: continue consuming and persisting events in the background
            # Use ActiveJob if available, otherwise fall back to threads
            if defined?(A2a::Rails::ProcessEventJob)
              _enqueue_background_consumption(task_id, queue, task_manager)
            else
              bg_thread = Thread.new do
                result_aggregator.consume_all(consumer)
              rescue StandardError
                # Log background consumption errors but don't raise
                # In production, you'd want proper logging here
              end
              bg_thread.name = "background_consume:#{task_id}"
              _track_background_task(bg_thread)
            end
            raise
          ensure
            # Use ActiveJob for cleanup if available
            if defined?(A2a::Rails::AgentExecutionJob)
              _enqueue_cleanup(task_id, producer_thread)
            else
              cleanup_thread = Thread.new do
                _cleanup_producer(producer_thread, task_id)
              end
              cleanup_thread.name = "cleanup_producer:#{task_id}"
              _track_background_task(cleanup_thread)
            end
          end
        end

        # Default handler for 'tasks/pushNotificationConfig/set'.
        #
        # @param params [Types::TaskPushNotificationConfig] Parameters including the task ID and push notification configuration.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::TaskPushNotificationConfig] The provided TaskPushNotificationConfig upon success.
        def on_set_task_push_notification_config(params, context = nil)
          raise ServerError, Types::JSONRPCError.new(code: -32_601, message: "Push notifications are not supported") unless @push_config_store

          @push_config_store.save(params, context)
        end

        # Default handler for 'tasks/pushNotificationConfig/get'.
        #
        # @param params [Types::TaskIdParams, Types::GetTaskPushNotificationConfigParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Types::TaskPushNotificationConfig] The TaskPushNotificationConfig for the task.
        def on_get_task_push_notification_config(params, context = nil)
          raise ServerError, Types::JSONRPCError.new(code: -32_601, message: "Push notifications are not supported") unless @push_config_store

          config = @push_config_store.get(params.id, params.respond_to?(:push_notification_config_id) ? params.push_notification_config_id : nil,
                                          context)
          raise ServerError, Types::JSONRPCError.new(code: -32_001, message: "Push notification config not found") unless config

          config
        end

        # Default handler for 'tasks/resubscribe'.
        #
        # Allows a client to re-subscribe to a running streaming task's event stream.
        #
        # @param params [Types::TaskIdParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @yield [Object] Event objects from the agent's ongoing execution
        # @return [Enumerator] An enumerator that yields Event objects
        def on_resubscribe_to_task(params, context = nil, &)
          return enum_for(:on_resubscribe_to_task, params, context) unless block_given?

          # Get or tap the existing queue for this task
          queue = @queue_manager.tap(params.id)
          raise ServerError, Types::JSONRPCError.new(code: -32_001, message: "Task not found or not streaming") unless queue

          consumer = Events::EventConsumer.new(queue)

          consumer.consume_all(&)
        end

        # Default handler for 'tasks/pushNotificationConfig/list'.
        #
        # @param params [Types::ListTaskPushNotificationConfigParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Array<Types::TaskPushNotificationConfig>] The list of TaskPushNotificationConfig for the task.
        def on_list_task_push_notification_config(params, context = nil)
          raise ServerError, Types::JSONRPCError.new(code: -32_601, message: "Push notifications are not supported") unless @push_config_store

          @push_config_store.list(params.id, context) || []
        end

        # Default handler for 'tasks/pushNotificationConfig/delete'.
        #
        # @param params [Types::DeleteTaskPushNotificationConfigParams] Parameters including the task ID.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [nil]
        def on_delete_task_push_notification_config(params, context = nil)
          raise ServerError, Types::JSONRPCError.new(code: -32_601, message: "Push notifications are not supported") unless @push_config_store

          @push_config_store.delete(params.id, params.push_notification_config_id, context)
        end

        private

        # Runs the agent's execute method and closes the queue afterwards.
        #
        # @param request_context [Object] The request context for the agent (must respond to task_id, message, etc.)
        # @param queue [Events::EventQueue] The event queue for the agent to publish to.
        def _run_event_stream(request_context, queue)
          @agent_executor.execute(request_context, queue)
        ensure
          queue.close
        end

        # Common setup logic for both streaming and non-streaming message handling.
        #
        # @param params [Types::MessageSendParams] Parameters including the message and configuration.
        # @param context [ServerCallContext, nil] Context provided by the server.
        # @return [Array] A tuple of (task_manager, task_id, queue, result_aggregator, producer_thread)
        # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        def _setup_message_execution(params, context = nil)
          # Create task manager and validate existing task
          # Note: This assumes a TaskManager interface exists. If not, this will need to be implemented.
          raise NotImplementedError, "TaskManager must be implemented for streaming" unless @task_manager_class

          task_manager = @task_manager_class.new(
            task_id: params.message.task_id,
            context_id: params.message.context_id,
            task_store: @task_store,
            initial_message: params.message,
            context: context
          )

          task = task_manager.get_task

          if task
            if TERMINAL_TASK_STATES.include?(task.status.state)
              raise ServerError, Types::JSONRPCError.new(
                code: -32_002,
                message: "Task #{task.id} is in terminal state: #{task.status.state}"
              )
            end

            task = task_manager.update_with_message(params.message, task) if task_manager.respond_to?(:update_with_message)
          elsif params.message.task_id
            raise ServerError, Types::JSONRPCError.new(
              code: -32_001,
              message: "Task #{params.message.task_id} was specified but does not exist"
            )
          end

          # Build request context
          # Note: This assumes a RequestContextBuilder interface exists
          request_context = if @request_context_builder
                              @request_context_builder.build(
                                params: params,
                                task_id: task&.id,
                                context_id: params.message.context_id,
                                task: task,
                                context: context
                              )
                            else
                              # Simple fallback - create a basic context object
                              # Using Hash instead of OpenStruct per RuboCop
                              {
                                task_id: task&.id || SecureRandom.uuid,
                                message: params.message,
                                context_id: params.message.context_id,
                                current_task: task
                              }
                            end

          task_id = (request_context.is_a?(Hash) ? request_context[:task_id] : request_context.task_id) || SecureRandom.uuid

          # Set push notification config if provided
          if @push_config_store && params.configuration&.push_notification_config
            @push_config_store&.set_info(task_id,
                                         params.configuration.push_notification_config)
          end

          # Create or tap the queue for this task
          queue = @queue_manager.create_or_tap(task_id)

          # Create result aggregator
          result_aggregator = Tasks::ResultAggregator.new(task_manager)

          # Start producer to run agent execution
          # Use ActiveJob if available, otherwise use threads
          if defined?(A2a::Rails::AgentExecutionJob) && @agent_executor.respond_to?(:class)
            # Store queue and request context for ActiveJob
            queue_id = _store_queue_for_job(queue)
            request_context_data = _serialize_request_context(request_context)

            job = A2a::Rails::AgentExecutionJob.perform_later(
              @agent_executor.class.name,
              request_context_data,
              queue_id
            )
            producer_thread = job # Treat job as the producer for tracking
          else
            # Fallback to thread-based execution
            producer_thread = Thread.new do
              _run_event_stream(request_context, queue)
            rescue StandardError => e
              # Store exception to be handled by consumer
              producer_thread[:exception] = e
              producer_thread[:exception_handler]&.call(e)
            end
            producer_thread.name = "agent_executor:#{task_id}"
          end

          _register_producer(task_id, producer_thread)

          [task_manager, task_id, queue, result_aggregator, producer_thread]
        end
        # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity

        # Registers the agent execution thread with the handler.
        #
        # @param task_id [String] The task ID
        # @param producer_thread [Thread] The thread running the agent execution
        def _register_producer(task_id, producer_thread)
          @running_agents_lock.synchronize do
            @running_agents[task_id] = producer_thread
          end
        end

        # Tracks a background task and logs exceptions on completion.
        #
        # @param thread [Thread] The background thread to track
        def _track_background_task(thread)
          @running_agents_lock.synchronize do
            @background_tasks << thread
          end

          # Set up exception handling for the thread
          Thread.new do
            thread.join
            begin
              # Check if thread raised an exception
              thread.value if thread.alive? == false
            rescue StandardError
              # Log exception (in production, use proper logging)
              # For now, we'll just track it
            ensure
              @running_agents_lock.synchronize do
                @background_tasks.delete(thread)
              end
            end
          end
        end

        # Cleans up the agent execution thread/job and queue manager entry.
        #
        # @param producer_thread [Thread, ActiveJob::Base] The thread or job running the agent execution
        # @param task_id [String] The task ID
        def _cleanup_producer(producer_thread, task_id)
          producer_thread.join if producer_thread.is_a?(Thread) && producer_thread.alive?
          @queue_manager.close(task_id)
          @running_agents_lock.synchronize do
            @running_agents.delete(task_id)
          end
        end

        # Enqueues background event consumption using ActiveJob.
        #
        # @param task_id [String] The task ID
        # @param queue [Events::EventQueue] The event queue
        # @param task_manager [Object] The task manager
        def _enqueue_background_consumption(task_id, queue, task_manager)
          queue_id = _store_queue_for_job(queue)
          task_manager_id = _store_task_manager_for_job(task_manager)
          A2a::Rails::ProcessEventJob.perform_later(task_id, queue_id, task_manager_id)
        end

        # Enqueues cleanup using ActiveJob.
        #
        # @param task_id [String] The task ID
        # @param producer_thread [Thread, ActiveJob::Base] The producer thread or job
        def _enqueue_cleanup(task_id, producer_thread)
          # Cleanup can be handled by the job completion callbacks
          # For now, we'll still call the cleanup method
          _cleanup_producer(producer_thread, task_id)
        end

        # Broadcasts an event to ActionCable subscribers.
        #
        # @param task_id [String] The task ID
        # @param event [Object] The event to broadcast
        def _broadcast_event(task_id, event)
          A2a::Rails::StreamingChannel.broadcast_event(task_id, event)
        end

        # Stores a queue for retrieval by ActiveJob (placeholder).
        #
        # @param queue [Events::EventQueue] The queue to store
        # @return [String] The queue identifier
        def _store_queue_for_job(queue)
          # In a real implementation, this would store the queue in Redis or similar
          # and return an identifier. For now, this is a placeholder.
          raise NotImplementedError, "Queue storage for ActiveJob must be implemented with Redis or similar"
        end

        # Stores a task manager for retrieval by ActiveJob (placeholder).
        #
        # @param task_manager [Object] The task manager to store
        # @return [String] The task manager identifier
        def _store_task_manager_for_job(task_manager)
          # In a real implementation, this would store the task manager state
          # and return an identifier. For now, this is a placeholder.
          raise NotImplementedError, "TaskManager storage for ActiveJob must be implemented"
        end

        # Serializes a request context for ActiveJob.
        #
        # @param request_context [Object, Hash] The request context
        # @return [Hash] Serialized context data
        def _serialize_request_context(request_context)
          # In a real implementation, this would serialize the context
          # For now, return a basic hash
          if request_context.is_a?(Hash)
            request_context
          else
            {
              task_id: request_context.task_id,
              context_id: request_context.context_id,
              message: request_context.message&.to_h,
              current_task: request_context.current_task&.to_h
            }
          end
        end

        # Validates that agent-generated task ID matches the expected task ID.
        #
        # @param task_id [String] The expected task ID
        # @param event_task_id [String] The task ID from the event
        def _validate_task_id_match(task_id, event_task_id)
          return if task_id == event_task_id

          raise ServerError, Types::JSONRPCError.new(
            code: -32_603,
            message: "Task ID mismatch: expected #{task_id}, got #{event_task_id}"
          )
        end

        # Sends push notification if configured and task is available.
        #
        # @param task_id [String] The task ID
        # @param result_aggregator [Tasks::ResultAggregator] The result aggregator
        def _send_push_notification_if_needed(task_id, result_aggregator)
          return unless @push_sender && task_id

          latest_task = result_aggregator.current_result
          return unless latest_task.is_a?(Types::Task)

          @push_sender.send_notification(latest_task)
        end
      end
    end
  end
end
