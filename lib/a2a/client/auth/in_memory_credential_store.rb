# frozen_string_literal: true

require_relative "credential_service"

module A2a
  module Client
    module Auth
      # A simple in-memory store for session-keyed credentials.
      #
      # This class uses the 'sessionId' from the CallContext state to
      # store and retrieve credentials.
      class InMemoryContextCredentialStore < CredentialService
        def initialize
          @store = {}
        end

        # Retrieves credentials from the in-memory store.
        #
        # @param security_scheme_name [String] The name of the security scheme
        # @param context [CallContext, nil] The client call context
        # @return [String, nil] The credential string, or nil if not found
        def get_credentials(security_scheme_name, context = nil)
          return nil unless context
          return nil unless context.state.is_a?(Hash)
          return nil unless context.state.key?("sessionId") || context.state.key?(:sessionId)

          session_id = context.state["sessionId"] || context.state[:sessionId]
          return nil unless session_id

          session_store = @store[session_id]
          return nil unless session_store

          session_store[security_scheme_name]
        end

        # Sets credentials in the store.
        #
        # @param session_id [String] The session ID
        # @param security_scheme_name [String] The name of the security scheme
        # @param credential [String] The credential value
        def set_credentials(session_id, security_scheme_name, credential)
          @store[session_id] ||= {}
          @store[session_id][security_scheme_name] = credential
        end
      end
    end
  end
end
