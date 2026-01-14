# frozen_string_literal: true

require_relative "client/errors"
require_relative "client/middleware"
require_relative "client/config"
require_relative "client/base"
require_relative "client/card_resolver"
require_relative "client/factory"
require_relative "client/base_client"
require_relative "client/task_manager"
require_relative "client/helpers"
require_relative "client/transports"

module A2a
  # Client-side components for interacting with an A2A agent
  module Client
  end
end
