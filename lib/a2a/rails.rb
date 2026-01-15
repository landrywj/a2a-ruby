# frozen_string_literal: true

module A2a
  # Rails integration module for A2A SDK.
  #
  # This module provides Rails-specific integrations:
  # - ActiveJob for background processing
  # - ActionCable for real-time streaming
  #
  # Note: These classes require Rails to be loaded. They are conditionally
  # required when Rails is available.
  module Rails
  end
end

# Conditionally load Rails-specific classes if Rails is available
if defined?(Rails)
  require_relative "rails/process_event_job"
  require_relative "rails/agent_execution_job"
  require_relative "rails/streaming_channel"
end
