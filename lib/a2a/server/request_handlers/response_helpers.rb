# frozen_string_literal: true

module A2a
  module Server
    module RequestHandlers
      # Helper functions for building A2A JSON-RPC responses.
      module ResponseHelpers
        # Helper method to build a JSONRPCErrorResponse wrapped in the appropriate response type.
        #
        # @param request_id [String, Integer, nil] The ID of the request that caused the error.
        # @param error [Types::JSONRPCError] The JSONRPCError object.
        # @return [Types::JSONRPCErrorResponse] A JSON-RPC error response
        def self.build_error_response(request_id, error)
          Types::JSONRPCErrorResponse.new(
            id: request_id,
            error: error
          )
        end

        # Helper method to build appropriate JSONRPCResponse object for RPC methods.
        #
        # Based on the type of the `response` object received from the handler,
        # it constructs either a success response wrapped in the appropriate payload type
        # or an error response.
        #
        # @param request_id [String, Integer, nil] The ID of the request.
        # @param response [Object] The object received from the request handler.
        # @param success_response_types [Array<Class>] An array of expected types for a successful result.
        # @param success_payload_type [Class] The class type for the success payload (e.g., SendMessageSuccessResponse).
        # @return [Types::JSONRPCSuccessResponse, Types::JSONRPCErrorResponse] A JSON-RPC response (success or error).
        def self.prepare_response_object(request_id, response, success_response_types, success_payload_type)
          # Check if response is one of the expected success types
          if success_response_types.any? { |type| response.is_a?(type) }
            return success_payload_type.new(
              id: request_id,
              result: response
            )
          end

          # If response is a JSONRPCError, return error response
          return build_error_response(request_id, response) if response.is_a?(Types::JSONRPCError)

          # If response is not an expected success type and not an error,
          # it's an invalid type of response from the agent for this specific method.
          error = Types::JSONRPCError.new(
            code: -32_603, # Internal error
            message: "Agent returned invalid type response for this method"
          )
          build_error_response(request_id, error)
        end
      end
    end
  end
end
