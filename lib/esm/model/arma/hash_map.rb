# frozen_string_literal: true

module ESM
  module Arma
    class HashMap < Hash
      # @param input [String, Array, Hash, OpenStruct] The data to be converted. If a String, data must be array pairs
      def self.parse(input)
        return if input.nil?

        self.new.merge!(parse_from_hash_map(input))
      rescue StandardError
        nil
      end

      # Goes over every item in the array and checks to see if an item needs converted to a hash
      # The normalization process follows these rules:
      #   Rule 1: Data can be an Array of any combination of the following: String, Scalar, Boolean, Array, or Hash (Defined as an array of pairs, with the first item being a string in all entries)
      #   Rule 2: To define a hash, create an array of pairs. Each pair must have a String as the first item and a valid JSON type as the second. This array cannot contain any other forms of items, otherwise it will be treated like an array. For example: [ [key1, value], [key2, value] ] -> { key1: value, key2: value }
      #   Rule 3: To define an Array, create an array of values. This will be converted as an array so long as all of the items in the array is not set up like Rule 2.
      #   Rule 4: To define an Array of hashes, create an array of array pairs. For example: [ [ [key, value] ], [ [ key, value], [key2, value] ] ] -> [{ key: value }, { key: value, key2: value }]
      def self.parse_from_hash_map(input)
        return {} if input.blank?

        input = input.to_h if input.respond_to?(:to_h)
        output = normalize_input(input)
        output.deep_symbolize_keys
      end

      # The parameters sent over by Arma can be in a SimpleArray format. This will convert the value if need be.
      # Parameters can be of type:
      def self.normalize_input(input)
        # The ending result of the sanitization
        sanitized_input = input

        if input.is_a?(OpenStruct) || input.is_a?(Hash) || (input.is_a?(Array) && valid_array_hash?(input))
          sanitized_input = input.to_h

          # Checks and converts the each item in the Hash/OpenStruct if needed
          sanitized_input.each do |key, value|
            sanitized_input[key] = normalize_input(value)
          end
        else
          # Integer, String, boolean, what have you
          return sanitized_input.to_s if sanitized_input.is_a?(Symbol)
          return sanitized_input if !sanitized_input.is_a?(Array)

          # Checks and converts the each item in the array if needed
          sanitized_input.each_with_index do |value, index|
            sanitized_input[index] = normalize_input(value)
          end
        end

        sanitized_input
      end

      # Checks if the array is set up to be able to be converted to a hash
      def self.valid_array_hash?(input)
        return false if !input.is_a?(Array)

        # Check if all items in the array are array pairs with the first item being a string
        correct_format =
          input.all? do |i|
            i.is_a?(Array) && i.size == 2 && i.first.is_a?(String)
          end

        return false if !correct_format

        # Check to make sure none of the keys are being reused
        keys = input.map(&:first)

        duplicates = keys.uniq!
        return true if duplicates.blank?

        # Log that duplicates were found
        ESM.logger.warn("#{self.class}##{__method__}") do
          ESM::JSON.pretty_generate(command: self.to_h, duplicated_keys: duplicates)
        end

        # There were duplicates found but the input will still be marked valid since it can be converted
        true
      end

      def initialize(**data)
        super.merge!(data)
      end

      def to_a
        convert_value =
          lambda do |value|
            case value
            when Array
              value.map { |v| convert_value.call(v) }
            when Hash
              value.deep_stringify_keys!
              value.each { |k, v| value[k] = convert_value.call(v) }

              # Convert the hash to array pairs
              value.to_a
            else
              value
            end
          end

        self.map do |key, value|
          [key.to_s, convert_value.call(value)]
        end
      end

      def to_json(*args)
        ::JSON.generate(self.to_a, *args)
      end

      alias_method :to_s, :to_json
    end
  end
end
