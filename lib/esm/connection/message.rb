# frozen_string_literal: true

module ESM
  class Connection
    class Message
      attr_reader :id, :server_id, :type, :data, :metadata, :errors
      attr_accessor :resource_id

      def self.from_string(string)
        json = string.to_h
        self.new(**json)
      end

      # @param server_id [String, nil]
      # @param type [String]
      # @param data [Hash]
      # @param metadata [Hash]
      # @param errors [Array<String>]
      def initialize(**args)
        @id = SecureRandom.uuid

        # The server provides the server_id as a UTF8 byte array. Convert it to a string
        @server_id =
          if args[:server_id].is_a?(Array)
            args[:server_id].pack("U*")
          else
            args[:server_id]
          end

        @type = args[:type] || ""
        @data = (args[:data] || {}).to_ostruct
        @data_type = args[:data_type] || "empty"
        @metadata = (args[:metadata] || {}).to_ostruct
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
