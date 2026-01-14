# frozen_string_literal: true

require_relative "a2a/version"
require_relative "a2a/types"
require_relative "a2a/utils"
require_relative "a2a/client"
require_relative "a2a/server"

module A2a
  class Error < StandardError; end
end
