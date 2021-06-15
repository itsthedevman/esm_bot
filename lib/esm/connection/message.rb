# frozen_string_literal: true

module ESM
  class Connection
    class Message
      attr_reader :id, :server_id, :type, :data, :metadata, :errors
      attr_accessor :resource_id

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
        @resource_id = json.resource_id
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
          id: self.id,
          server_id: self.server_id,
          resource_id: self.resource_id,
          type: self.type,
          data: self.data.to_h,
          metadata: self.metadata.to_h,
          errors: self.errors.map(&:to_h)
        }
      end
    end
  end
end
