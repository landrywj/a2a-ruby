# frozen_string_literal: true

require_relative "server/context"
require_relative "server/errors"
require_relative "server/events"
require_relative "server/tasks"
require_relative "server/request_handlers/request_handler"
require_relative "server/request_handlers/jsonrpc_handler"
require_relative "server/request_handlers/rest_handler"
require_relative "server/request_handlers/default_request_handler"
require_relative "server/request_handlers/response_helpers"

module A2a
  # Server module for A2A protocol server-side implementation.
  #
  # This module provides server-side components for handling A2A protocol requests,
  # including request handlers, event management, and task processing.
  module Server
  end
end
