# frozen_string_literal: true

module ESM
  module Arma
    class HashMap < ActiveSupport::HashWithIndifferentAccess
      # @param input [String, Array, Hash, OpenStruct] The data to be converted. If a String, data must be array pairs
      def self.from(input)
        hash_map = self.new
        return hash_map if input.blank?

        hash_map.from(input)
      rescue StandardError
        nil
      end

      def initialize(data = {})
        super
        return if data.blank?

        from(data)
      end

      def from(input)
        hash = normalize(input)
        merge!(hash)

        hash
      end

      def to_a
        convert_value =
          lambda do |value|
            case value
            when Array
              value.map { |v| convert_value.call(v) }
            when Hash
              value.each_with_object([[], []]) do |(k, v), array|
                array.first << convert_value.call(k)
                array.second << convert_value.call(v)
              end
            when Symbol
              value.to_s
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

      private

      # The parameters sent over by Arma can be in a SimpleArray format. This will convert the value if need be.
      # Parameters can be of type:
      def normalize(input)
        case input
        when OpenStruct, Struct, Hash
          input = input.to_h
          return if input.nil?

          input.transform_values { |v| normalize(v) }
        when Array, String
          hash = input.to_a
          if valid_hash_map?(hash)
            keys = hash.first
            values = hash.second

            keys.each_with_object({}).with_index do |(key, obj), index|
              obj[key] = normalize(values[index])
            end
          elsif hash.is_a?(Array)
            input.map { |i| normalize(i) }
          else
            input
          end
        when Symbol
          input.to_s
        else
          input
        end
      end

      # Checks if the array is set up to be able to be converted to a hash
      # The input must be an array and in the format of [[keys], [values]]
      def valid_hash_map?(input)
        input.is_a?(Array) && input.size == 2 && input.all?(Array) && input.first.size >= input.second.size
      end
    end
  end
end
