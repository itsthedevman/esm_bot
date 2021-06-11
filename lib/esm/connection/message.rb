# frozen_string_literal: true

module ESM
  class Connection
    class Message
      attr_reader :id, :server_id, :type, :data, :metadata, :errors

      # @param server_id [String, nil]
      # @param type [String]
      # @param data [Hash]
      # @param metadata [Hash]
      # @param errors [Array<String>]
      def initialize(**args)
        @id = SecureRandom.uuid
        @server_id = args[:server_id]
        @type = args[:type] || ""
        @data = (args[:data] || {}).to_ostruct
        @metadata = (args[:metadata] || {}).to_ostruct
        @errors = args[:errors] || []
      end

      def from_string(json)
        json = json.to_ostruct

        @id = json.id
        @server_id = json.server_id
        @type = json.type
        @data = json.data
        @metadata = json.metadata
        @errors = json.errors
      end

      def to_s
        to_h.to_json
      end

      def to_h
        {
          id: @id,
          server_id: @server_id,
          type: @type,
          data: @data.to_h,
          metadata: @metadata.to_h,
          errors: @errors
        }
      end
    end
  end
end
