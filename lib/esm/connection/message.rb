# frozen_string_literal: true

module ESM
  class Connection
    class Message
      include ESM::Callbacks

      MAPPINGS = YAML.safe_load(File.read(File.expand_path("./config/message_type_mapping.yml")), symbolize_names: true).freeze
      ARRAY_REGEX = /array<(?<type>.+)>/i.freeze

      attr_reader :id, :server_id, :type, :data, :metadata, :errors, :data_type, :metadata_type, :router_options
      attr_accessor :resource_id

      # These callbacks correspond to events sent from the server.
      # Events:
      #   on_response   -   Called when a message receives a response to its contents.
      #                     Message does not implement this callback by default
      register_callbacks :on_response

      def self.from_string(json)
        data_hash = json.to_h

        # Unpack the data and metadata
        data_hash[:data_type] = data_hash.dig(:data, :type) || "empty"
        data_hash[:data] = data_hash.dig(:data, :content)

        data_hash[:metadata_type] = data_hash.dig(:metadata, :type) || "empty"
        data_hash[:metadata] = data_hash.dig(:metadata, :content)

        # Convert based on the mapping
        data_hash[:convert_types] = true

        self.new(**data_hash)
      end

      # The driver of communication between the bot, server, and client.
      #
      # @param convert_types [true/false] Runs the message's data values against the pre-configured mapping and perform any type conversions if needed
      # @param server_id [String, Array<Integer>, nil] The ID of the server this messages should be sent to. Array<Integer> will be converted to string automatically
      # @param type [String] The type of message. This gives context to the message
      # @param data [Hash] The primary data for this message. It's the good stuff.
      # @param metadata [Hash] Any extra data that may be needed. For most command messages, this will contain the user's discord and steam data.
      # @param errors [Array<Hash>] Any errors that were caused by this message.
      #                             Each hash has the following attributes:
      #                               type [String] The type of error. Valid options are:
      #                                               "code" # Uses the message to look up a predefined message in the locales
      #                                               "message" # Treats the message like a string and sends it as is
      #                               message [String] The content of this error.
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
        @metadata = OpenStruct.new(args[:metadata] || {})
        @data_type = args[:data_type] || args[:type].presence || "empty"
        @metadata_type = args[:metadata_type] || "empty"
        @errors = args[:errors] || []
        @routing_data = OpenStruct.new(command: nil)

        self.convert_types(data, message_type: @data_type) if args[:convert_types]
      end

      # Sets the various config options used by the overseer when routes the message
      #
      # @param command [ESM::Command] The command that triggered this message. The overseer uses this hook back into the command
      def routing_data(**opts)
        opts.each { |key, value| @routing_data.send("#{key}=", value) }
      end

      # If this Message was provided a command, calling this method will automatically add the user's discord and steam info to the metadata
      # This is done separately because not every message type will use the data. It would be a waste to send it over the wire if it's not used
      def apply_user_metadata
        command = @routing_data.command
        return if command.nil? || command.current_user.blank?

        user = command.current_user
        @metadata[:user_id] = user.id.to_s
        @metadata[:user_name] = user.username
        @metadata[:user_mention] = user.mention
        @metadata[:user_steam_uid] = user.steam_uid
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

      private

      # Converts a hash's data based on the provided type mapping.
      # @see config/message_type_mapping.yml for more information
      def convert_types(data, message_type:, mapping: {})
        mapping = MAPPINGS[message_type.to_sym] if mapping.blank?

        # Catches if MAPPINGS does not have type defined
        raise ESM::Exception::Error, "Failed to find type \"#{message_type}\" in \"message_type_mapping.yml\"" if mapping.nil?

        data.each do |key, value|
          mapping_class = mapping[key.to_sym]
          raise ESM::Exception::Error, "Failed to find key \"#{key}\" in mapping for \"#{message_type}\"" if mapping_class.nil?

          # Check for HashMap since it's not a base Ruby class
          mapping_klass =
            case mapping_class
            when "HashMap"
              ESM::Arma::HashMap
            when ARRAY_REGEX
              NilClass # Use the exact opposite to skip the check below
            else
              mapping_class.constantize
            end

          next if value.is_a?(mapping_klass)

          # Perform the conversion and replace the value
          data[key] = convert_type(value, message_type: message_type, into_type: mapping_class, data_key: key)
        end
      end

      # TODO: Documentation
      def convert_type(value, message_type:, into_type:, data_key:)
        return value if value.class.to_s == into_type

        case into_type
        when ARRAY_REGEX
          match = into_type.match(ARRAY_REGEX)
          raise ESM::Exception::Error, "Failed to parse inner type from \"#{into_type}\" in mapping for \"#{message_type}\"" if match.nil?

          # Convert the inner values to whatever type is configured
          value.to_a.map { |v| convert_type(v, message_type: message_type, into_type: match[:type], data_key: data_key) }
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
          raise ESM::Exception::Error, "Value #{value} has an invalid type \"#{into_type}\" mapped to \"#{data_key}\" in mapping for \"#{message_type}\"."
        end
      end
    end
  end
end
