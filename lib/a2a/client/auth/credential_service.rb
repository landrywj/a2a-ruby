# frozen_string_literal: true

require_relative "../../client/middleware"

module A2a
  module Client
    module Auth
      # An abstract service for retrieving credentials.
      class CredentialService
        # Retrieves a credential (e.g., token) for a security scheme.
        #
        # @param security_scheme_name [String] The name of the security scheme
        # @param context [CallContext, nil] The client call context
        # @return [String, nil] The credential string, or nil if not found
        def get_credentials(security_scheme_name, context = nil)
          raise NotImplementedError, "Subclasses must implement #get_credentials"
        end
      end
    end
  end
end
