# frozen_string_literal: true

module A2a
  module Auth
    # A representation of an authenticated user.
    class User
      # Returns whether the current user is authenticated.
      #
      # @return [Boolean] true if authenticated, false otherwise
      def is_authenticated
        raise NotImplementedError, "Subclasses must implement #is_authenticated"
      end

      # Returns the user name of the current user.
      #
      # @return [String] The user name
      def user_name
        raise NotImplementedError, "Subclasses must implement #user_name"
      end
    end

    # A representation that no user has been authenticated in the request.
    class UnauthenticatedUser < User
      # Returns whether the current user is authenticated.
      #
      # @return [Boolean] Always returns false
      def is_authenticated
        false
      end

      # Returns the user name of the current user.
      #
      # @return [String] Always returns an empty string
      def user_name
        ""
      end
    end
  end
end
