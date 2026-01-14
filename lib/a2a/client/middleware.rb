# frozen_string_literal: true

module A2a
  module Client
    # A context passed with each client call, allowing for call-specific
    # configuration and data passing. Such as authentication details or
    # request deadlines.
    class CallContext
      attr_accessor :state

      def initialize(state = {})
        @state = state || {}
      end
    end

    # An abstract base class for client-side call interceptors.
    # Interceptors can inspect and modify requests before they are sent,
    # which is ideal for concerns like authentication, logging, or tracing.
    class CallInterceptor
      # Intercepts a client call before the request is sent.
      #
      # @param method_name [String] The name of the RPC method (e.g., 'message/send')
      # @param request_payload [Hash] The JSON RPC request payload dictionary
      # @param http_kwargs [Hash] The keyword arguments for the HTTP request
      # @param agent_card [Types::AgentCard, nil] The AgentCard associated with the client
      # @param context [CallContext, nil] The CallContext for this specific call
      # @return [Array<Hash, Hash>] A tuple containing the (potentially modified) request_payload and http_kwargs
      def intercept(method_name, request_payload, http_kwargs, agent_card = nil, context = nil)
        raise NotImplementedError, "Subclasses must implement #intercept"
      end
    end
  end
end
