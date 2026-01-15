# frozen_string_literal: true

require "set"

module A2a
  module Server
    # A context passed when calling a server method.
    # This class allows storing arbitrary user data in the state attribute.
    class ServerCallContext
      attr_accessor :state, :user, :requested_extensions, :activated_extensions

      def initialize(attributes = {})
        @state = attributes[:state] || attributes["state"] || {}
        @user = attributes[:user] || attributes["user"] || Auth::UnauthenticatedUser.new
        @requested_extensions = attributes[:requested_extensions] || attributes["requestedExtensions"] || Set.new
        @activated_extensions = attributes[:activated_extensions] || attributes["activatedExtensions"] || Set.new
      end

      def to_h
        {
          state: @state,
          user: @user,
          requested_extensions: @requested_extensions.to_a,
          activated_extensions: @activated_extensions.to_a
        }
      end
    end
  end
end
