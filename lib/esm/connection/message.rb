# frozen_string_literal: true

module ESM
  class Connection
    class Message
      MAPPINGS = YAML.safe_load(File.read(File.expand_path("./config/message_type_mapping.yml")), symbolize_names: true).freeze

      attr_reader :id, :server_id, :type, :data, :metadata, :errors, :data_type, :metadata_type
      attr_accessor :resource_id

      def self.from_string(json)
        data_hash = json.to_h

        # Unpack the data and metadata
        data_hash[:data_type] = data_hash.dig(:data, :type)
        data_hash[:data] = data_hash.dig(:data, :content)

        data_hash[:metadata_type] = data_hash.dig(:metadata, :type)
        data_hash[:metadata] = data_hash.dig(:metadata, :content)

        # Perform any conversions to the data according to the mapping
        data = data_hash[:data]
        type = data_hash[:data_type]
        self.convert_types(data, type: type)

        self.new(**data_hash)
      end

      # Converts a hash's data based on the provided type mapping.
      # @see config/message_type_mapping.yml for more information
      def self.convert_types(data, type:, mapping: {})
        mapping = MAPPINGS[type.to_sym] if mapping.blank?

        data.each do |key, value|
          mapping_class = mapping[key.to_sym]
          raise ESM::Exception::Error, "Failed to find key \"#{key}\" in mapping for \"#{type}\"" if mapping_class.nil?

          # Check for HashMap since it's not a base Ruby class
          mapping_klass =
            if mapping_class == "HashMap"
              ESM::Arma::HashMap
            else
              mapping_class.constantize
            end

          next if value.is_a?(mapping_klass)

          # Perform the conversion and replace the value
          # This cannot use a Class === Class conversion.
          data[key] =
            case mapping_class
            when "Array"
              value.to_a
            when "String"
              value.to_s
            when "Integer"
              value.to_i
            when "Hash"
              value.to_h
            when "HashMap"
              ESM::Arma::HashMap.new(value)
            when "DateTime"
              ::DateTime.parse(value)
            when "Date"
              ::Date.parse(value)
            else
              raise ESM::Exception::Error, "Invalid type \"#{mapping_class}\" mapped to \"#{key}\" in mapping for \"#{data_hash[:data_type]}\""
            end
        end
      end

      # @param server_id [String, nil]
      # @param type [String]
      # @param data [Hash]
      # @param metadata [Hash]
      # @param errors [Array<String>]
      def initialize(**args)
        @id = args[:id] || SecureRandom.uuid

        # The server provides the server_id as a UTF8 byte array. Convert it to a string
        @server_id =
          if args[:server_id].is_a?(Array)
            args[:server_id].pack("U*")
          else
            args[:server_id]
          end

        @type = args[:type] || ""
        @data = OpenStruct.new(args[:data] || {})
        @data_type = args[:data_type] || "empty"
        @metadata = OpenStruct.new(args[:metadata] || {})
        @metadata_type = args[:metadata_type] || "empty"
        @errors = args[:errors] || []
      end

      def to_s
        to_h.to_json
      end

      def to_h
        {
          id: self.id,
          server_id: self.server_id&.bytes,
          resource_id: self.resource_id,
          type: self.type,
          data: {
            type: @data_type,
            content: self.data.to_h
          },
          metadata: {
            type: @metadata_type,
            content: self.metadata.to_h
          },
          errors: self.errors.map(&:to_h)
        }
      end
    end
  end
end
