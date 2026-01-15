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
  module Server
    # Server module for A2A protocol server-side implementation
  end
end
