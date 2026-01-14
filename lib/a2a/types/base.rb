# frozen_string_literal: true

module A2a
  module Types
    # Base class for A2A data models
    # Provides common serialization and validation behavior
    class BaseModel
      attr_accessor :metadata

      def initialize(attributes = {})
        # Handle case where attributes might be a hash or respond to hash-like access
        if attributes.is_a?(Hash)
          @metadata = attributes[:metadata] || attributes["metadata"]
          set_attributes(attributes)
        else
          # If it's not a hash, try to set attributes from the object itself
          @metadata = attributes.respond_to?(:metadata) ? attributes.metadata : nil
          set_attributes_from_object(attributes)
        end
      end

      # Convert to hash for JSON serialization
      def to_h
        hash = {}
        instance_variables.each do |var|
          key = var.to_s.delete_prefix("@").to_sym
          value = instance_variable_get(var)
          next if value.nil? && !include_nil?

          # Convert camelCase for JSON serialization
          json_key = to_camel_case(key.to_s)
          hash[json_key] = serialize_value(value)
        end
        hash
      end

      # Convert to JSON string
      def to_json(*args)
        require "json"
        to_h.to_json(*args)
      end

      # Create instance from hash
      def self.from_h(hash)
        # The new method already handles both camelCase and snake_case keys
        # So we can just pass the hash directly
        new(hash)
      end

      # Create instance from JSON string
      def self.from_json(json_string)
        require "json"
        from_h(JSON.parse(json_string))
      end

      protected

      def set_attributes(attributes)
        attributes.each do |key, value|
          method_name = "#{key}="
          send(method_name, value) if respond_to?(method_name)
        end
      end

      def set_attributes_from_object(obj)
        # Try to set attributes from object's accessors
        instance_variables.each do |var|
          attr_name = var.to_s.delete_prefix("@").to_sym
          if obj.respond_to?(attr_name)
            method_name = "#{attr_name}="
            send(method_name, obj.send(attr_name)) if respond_to?(method_name)
          end
        end
      end

      def serialize_value(value)
        case value
        when BaseModel
          value.to_h
        when Array
          value.map { |item| serialize_value(item) }
        when Hash
          value.transform_keys { |k| to_camel_case(k.to_s) }
        else
          value
        end
      end

      def to_camel_case(snake_str)
        # Handle special cases like trailing underscores
        snake_str = snake_str.chomp("_")
        parts = snake_str.split("_")
        first = parts.shift
        first + parts.map(&:capitalize).join
      end

      def include_nil?
        false
      end
    end
  end
end
