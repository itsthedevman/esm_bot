# frozen_string_literal: true

module ESM
  class Connection
    class Message
      include ESM::Callbacks

      MAPPINGS = YAML.safe_load(File.read(File.expand_path("./config/message_type_mapping.yml")), symbolize_names: true).freeze
      ARRAY_REGEX = /array<(?<type>.+)>/i.freeze

      attr_reader :id, :server_id, :type, :data, :metadata, :errors, :data_type, :metadata_type
      attr_accessor :resource_id

      # All callbacks are provided with two arguments:
      #   incoming_message [ESM::Connection::Message, nil]  The incoming message from the client, if applicable.
      #   outgoing_message [ESM::Connection::Message, nil]  The outgoing message sent through the server, if applicable.
      #
      # Available callbacks:
      #   on_response
      #     - Called when a message receives a response to its contents.
      #   on_error
      #     - Called when a message experienced an error.
      register_callbacks :on_response, :on_error
      add_callback :on_error, :on_error

      #
      # Creates an instance of ESM::Connection::Message from JSON. See #to_h for the structure
      # @see #to_h
      #
      # @param json [String] The JSON to parse
      #
      # @return [Self]
      #
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
      # @param type [String] The type of message this is
      # @param args [Hash]
      # @option args [String, Array<Integer>, nil] :server_id The ID of the server this messages should be sent to. Array<Integer> will be converted to string automatically
      # @option args [String] :type The type of message. This gives context to the message
      # @option args [Hash] :data The primary data for this message. It's the good stuff.
      # @option args [Hash] :metadata Any extra data that may be needed. For most command messages, this will contain the user's discord and steam data.
      # @option args [Array<Hash>] :errors Any errors that were caused by this message.
      #   Each hash has the following attributes:
      #     type [String] The type of error. Valid options are:
      #       "code" # Uses the message to look up a predefined message in the locales
      #       "message" # Treats the message like a string and sends it as is
      #     message [String] The content of this error.
      # @option args [String] :data_type The name of the type that gives the "data" its structure.
      # @option args [String] :metadata_type The name of the type that gives the "metadata" its structure.
      # @option args [Boolean] :convert_types Runs the message's data values against the pre-configured mapping and perform any type conversions if needed
      def initialize(type:, **args)
        @id = args[:id] || SecureRandom.uuid

        # The server provides the server_id as a UTF8 byte array. Convert it to a string
        @server_id =
          if args[:server_id].is_a?(Array)
            args[:server_id].pack("U*")
          else
            args[:server_id]
          end

        @type = type
        @data = OpenStruct.new(args[:data] || {})
        @metadata = OpenStruct.new(args[:metadata] || {})
        @data_type = args[:data_type] || args[:type].presence || "empty"
        @metadata_type = args[:metadata_type] || "empty"
        @errors = (args[:errors] || []).map(&:to_ostruct)
        @routing_data = OpenStruct.new(command: nil)
        @delivered = false

        self.convert_types(data, message_type: @data_type) if args[:convert_types]
      end

      # Sets the various config options used by the overseer when routes the message
      #
      # @param opts [Hash]
      # @option opts [ESM::Command] :command The command that triggered this message. The overseer uses this hook back into the command
      def routing_data(**opts)
        opts.each { |key, value| @routing_data.send("#{key}=", value) }
        self
      end

      #
      # Sets the user's ID, name, mention, and steam uid to the metadata for this message.
      # This only applies to messages that have a command in their routing data
      #
      # @note If this Message was provided a command, calling this method will automatically add the user's discord and steam info to the metadata
      #   This is done separately because not every message type will use the data. It would be a waste to send it over the wire if it's not used
      def apply_user_metadata
        user = @routing_data.try(:command).try(:current_user)
        return if user.nil?

        @metadata[:user_id] = user.id.to_s
        @metadata[:user_name] = user.username
        @metadata[:user_mention] = user.mention
        @metadata[:user_steam_uid] = user.steam_uid
      end

      #
      # Adds the provided error to this message
      #
      # @param type [String] The error type. Valid types are: "code" and "message"
      # @param message [String] The message or code for this error
      #
      def add_error(type:, content:)
        @errors << OpenStruct.new(type: type, content: content)
      end

      #
      # Converts the message to JSON
      #
      # @return [String] The message as JSON
      #
      def to_s
        to_h.to_json
      end

      #
      # Converts the message to a Hash
      #
      # @return [Hash] The message as a Hash. It has the following keys
      #   {
      #     id: The ID of this message as a UUID
      #     server_id: The server ID this message is being sent to or from as a byte array
      #     resource_id: The internal resource ID used by tcp_server
      #     type: The context of this message
      #     data: {
      #       type: Describes the structure of content
      #       content: The actual "data"
      #     },
      #     metadata: {
      #       type: Describes the structure of content
      #       content: The actual "metadata"
      #     },
      #     errors: Any errors associated to this message
      #   }
      #
      def to_h
        data = self.data.to_h
        metadata = self.metadata.to_h

        {
          id: self.id,
          server_id: self.server_id&.bytes,
          resource_id: self.resource_id,
          type: self.type,
          data: {
            type: @data_type,
            content: data.present? ? data : nil
          },
          metadata: {
            type: @metadata_type,
            content: metadata.present? ? metadata : nil
          },
          errors: self.errors.map(&:to_h)
        }
      end

      #
      # Returns if there is any data on this message
      #
      # @return [Boolean]
      #
      def data?
        self.data.to_h.present?
      end

      #
      # Returns if there is any metadata on this message
      #
      # @return [Boolean]
      #
      def errors?
        self.errors.any?
      end

      #
      # Used by MessageOverseer, this returns if the message has been delivered and is no longer needing to be watched
      #
      # @return [Boolean]
      #
      def delivered?
        @delivered
      end

      #
      # Sets the delivered flag to true.
      # @see #delivered?
      #
      # @return [true]
      #
      def delivered
        @delivered = true
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
            when "Boolean", ARRAY_REGEX
              NilClass # Use the exact opposite to skip the check below
            when "Decimal"
              BigDecimal
            else
              mapping_class.constantize
            end

          next if value.is_a?(mapping_klass)

          # Perform the conversion and replace the value
          data[key] = convert_type(value, message_type: message_type, into_type: mapping_class, data_key: key)
        end
      end

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
        when "Decimal"
          value.to_d
        when "Boolean"
          value.to_s == "true"
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

      def on_error(incoming_message, _outgoing_message)
        # For now, only support a single error until multiple error support is needed
        error = incoming_message.errors.first

        description =
          case error.type
          when "code"
            replacements = {
              user: @routing_data.try(:command).try(:current_user).try(:mention),
              message_id: incoming_message.id,
              server_id: incoming_message.server_id,
              type: incoming_message.type,
              data_type: incoming_message.data_type,
              mdata_type: incoming_message.metadata_type
            }

            # Add the data and metadata to the replacements
            # For example, if data has two attributes: "steam_uid" and "discord_id", this will define two replacements:
            #     "data_content_steam_uid", and "data_content_discord_id"
            #
            # Same for metadata's attributes. Except the key prefix is "mdata_content_"
            incoming_message.data.to_h.each { |key, value| replacements["data_content_#{key}".to_sym] = value }
            incoming_message.metadata.to_h.each { |key, value| replacements["mdata_content_#{key}".to_sym] = value }

            # Call the exception with the replacements
            I18n.t("exceptions.extension.#{error.content}", **replacements)
          when "message"
            error.content
          when "embed"
            # A special type only available to the bot. Used internally
            return error.content
          else
            I18n.t("exceptions.extension.default", type: error.type)
          end

        embed = ESM::Embed.build(:error, description: description)

        # Attempt to send the embed through the command
        @routing_data.try(:command).try(:reply, embed)

        embed
      end
    end
  end
end
