# frozen_string_literal: true

require_relative "a2a/version"
require_relative "a2a/types"
require_relative "a2a/utils"
require_relative "a2a/client"
require_relative "a2a/server"

# Conditionally load Rails integration if Rails is available
if defined?(Rails) || defined?(ActiveJob) || defined?(ActionCable)
  require_relative "a2a/rails"
end

module A2a
  class Error < StandardError; end
end
