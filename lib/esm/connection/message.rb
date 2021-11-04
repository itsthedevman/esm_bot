# frozen_string_literal: true

module ESM
  class Connection
    class Message
      include ESM::Callbacks

      MAPPING = YAML.safe_load(File.read(File.expand_path("./config/mapping.yml")), symbolize_names: true).freeze
      ARRAY_REGEX = /array<(?<type>.+)>/i.freeze

      class Error
        def initialize(message, type:, content:)
          @message = message
          @type = type
          @content = content
        end

        def to_h
          {
            type: @type,
            content: @content
          }
        end

        def to_s
          case @type
          when "code"
            replacements = {
              user: @message.routing_data.try(:command).try(:current_user).try(:mention),
              message_id: @message.id,
              server_id: @message.server_id,
              type: @message.type,
              data_type: @message.data_type,
              mdata_type: @message.metadata_type
            }

            # Add the data and metadata to the replacements
            # For example, if data has two attributes: "steam_uid" and "discord_id", this will define two replacements:
            #     "data_content_steam_uid", and "data_content_discord_id"
            #
            # Same for metadata's attributes. Except the key prefix is "mdata_content_"
            @message.data.to_h.each { |key, value| replacements["data_content_#{key}".to_sym] = value }
            @message.metadata.to_h.each { |key, value| replacements["mdata_content_#{key}".to_sym] = value }

            # Call the exception with the replacements
            I18n.t("exceptions.extension.#{@content}", **replacements)
          when "message"
            @content
          else
            I18n.t("exceptions.extension.default", type: @type)
          end
        end
      end

      attr_reader :id, :type, :data, :metadata, :errors, :data_type, :metadata_type, :routing_data
      attr_accessor :resource_id, :server_id

      # All callbacks are provided with two arguments:
      #   incoming_message [ESM::Connection::Message, nil]  The incoming message from the client, if applicable.
      #   outgoing_message [ESM::Connection::Message, nil]  The outgoing message sent through the server, if applicable.
      #
      # Available callbacks:
      #   on_response
      #     - Called when a message receives a response to its contents.
      #   on_error
      #     - Called when a message experienced an error.
      #     - There is a default implementation called "on_error". To use it, call `message.add_callback(:on_error, :on_error)`
      register_callbacks :on_response, :on_error

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

        self.new(**data_hash)
      end

      # The driver of communication between the bot, server, and client. Rust is strict so this has to be too.
      # Any data and metadata must be configured in config/mapping.yml and defined in esm_message -> data.rs / metadata.rs
      # They will automatically be sanitized according to their data type as configured in the mapping.
      # NOTE: Invalid data/metadata attributes will be dropped!
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
      def initialize(type:, **args)
        @id = args[:id] || SecureRandom.uuid
        @type = type

        # The server provides the server_id as a UTF8 byte array. Convert it to a string
        @server_id =
          if args[:server_id].is_a?(Array)
            args[:server_id].pack("U*")
          else
            args[:server_id]
          end

        # If there is data and no data_type provided, default to the message's type. Otherwise, consider it "empty"
        @metadata_type = args[:metadata_type] || "empty"
        @data_type =
          if args[:data_type]
            args[:data_type]
          elsif args[:data].present?
            type
          else
            "empty"
          end

        @metadata = OpenStruct.new(self.sanitize(args[:metadata].to_h || {}, @metadata_type))
        @data = OpenStruct.new(self.sanitize(args[:data].to_h || {}, @data_type))
        @errors = (args[:errors] || []).map { |e| Error.new(self, **e) }
        @routing_data = OpenStruct.new(command: nil)
        @delivered = false
        @mutex = Mutex.new
      end

      # Sets the various config options used by the overseer when routes the message
      #
      # @param opts [Hash]
      # @option opts [ESM::Command] :command The command that triggered this message. The overseer uses this hook back into the command
      def add_routing_data(**opts)
        opts.each { |key, value| @routing_data.send("#{key}=", value) }
        self
      end

      #
      # Sets the user's ID, name, mention, and steam uid to the metadata for this message. Will also do the same for the target user if the command has one
      # This only applies to messages that have a command in their routing data
      #
      def apply_command_metadata
        user = @routing_data.try(:command).try(:current_user)
        return if user.nil?

        @metadata_type = "command"
        @metadata.player = {
          steam_uid: user.steam_uid,
          discord_id: user.id.to_s,
          discord_name: user.username,
          discord_mention: user.mention
        }

        target_user = @routing_data.try(:command).try(:target_user)
        return if target_user.nil?

        @metadata.target = {
          steam_uid: target_user.steam_uid,
          discord_id: target_user.id.to_s,
          discord_name: target_user.username,
          discord_mention: target_user.mention
        }
      end

      #
      # Adds the provided error to this message
      #
      # @param type [String] The error type. Valid types are: "code" and "message"
      # @param message [String] The message or code for this error
      #
      def add_error(type:, content:)
        @errors << Error.new(self, type: type, content: content)
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

        # Numbers have to be sent as Strings
        data.transform_values! { |val| val.is_a?(Numeric) ? val.to_s : val }
        metadata.transform_values! { |val| val.is_a?(Numeric) ? val.to_s : val }

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

      #
      # Set's the message as synchronous
      # This sets the message's callbacks and forces `ESM::Connection::Server#send_message` to become blocking
      #
      def synchronous
        self.add_callback(:on_response, :on_response_sync)
        self.add_callback(:on_error, :on_error_sync)
      end

      #
      # Waits for a synchronous message to receive a response or timeout
      #
      # @return [ESM::Connection::Message] The incoming message containing the response or errors
      #
      def wait_for_response
        # Waits 2 minutes. This is a backup in case message overseer doesn't time it out
        counter = 0
        while @incoming_message.nil? || counter >= 240
          sleep(0.5)
          counter += 1
        end

        # This should never raise. It's for emergencies
        raise ESM::Exception::MessageSyncTimeout if counter >= 240

        @incoming_message
      end

      def inspect
        "#<ESM::Message:0x#{object_id} #{JSON.pretty_generate(self.to_h)}>"
      end

      private

      # Sanitizes the provided data in accordance to the data defined in config/mapping.yml
      # Sanitize also ensures the order of the data when exporting
      # @see config/mapping.yml for more information
      def sanitize(data, data_type)
        mapping = MAPPING[data_type.to_sym]

        # Catches if MAPPINGS does not have type defined
        raise ESM::Exception::InvalidMessage, "Failed to find type \"#{data_type}\" in \"config/mapping.yml\"" if mapping.nil?

        output = {}
        mapping.each do |attribute_name, attribute_type|
          data_entry = data.delete(attribute_name)
          raise ESM::Exception::InvalidMessage, "\"#{attribute_name}\" was not provided for \"#{data_type}\"" if data_entry.nil?

          # Some classes are not valid ruby classes and need converted
          klass =
            case attribute_type
            when "HashMap"
              ESM::Arma::HashMap
            when "Boolean", ARRAY_REGEX
              NilClass # Always convert theses
            when "Decimal"
              BigDecimal
            else
              attribute_type.constantize
            end

          output[attribute_name] =
            if data_entry.is_a?(klass)
              data_entry
            else
              # Perform the conversion and replace the value
              convert_type(data_entry, into_type: attribute_type)
            end
        rescue StandardError => e
          ESM::Notifications.trigger(
            "error",
            class: self.class, method: __method__, error: e,
            attribute_name: attribute_name, attribute_type: attribute_type
          )
        end

        output
      end

      def convert_type(value, into_type:)
        return value if value.class.to_s == into_type

        case into_type
        when ARRAY_REGEX
          match = into_type.match(ARRAY_REGEX)
          raise ESM::Exception::Error, "Failed to parse inner type from \"#{into_type}\"" if match.nil?

          # Convert the inner values to whatever type is configured
          value.to_a.map { |v| convert_type(v, into_type: match[:type]) }
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
          ESM::Arma::HashMap.parse(value)
        when "DateTime"
          ::DateTime.parse(value)
        when "Date"
          ::Date.parse(value)
        else
          raise ESM::Exception::Error, "\"#{into_type}\" is an unsupported type"
        end
      end

      def on_error(incoming_message, _outgoing_message)
        # For now, only support a single error until multiple error support is needed
        error = incoming_message.errors.first
        embed = ESM::Embed.build(:error, description: error.to_s)

        # Attempt to send the embed through the command
        @routing_data.try(:command).try(:reply, embed)

        ESM::Notifications.trigger("error", class: self.class, method: __method__, error: error.to_h)

        embed
      end

      #
      # Used when a message needs to be treated like its synchronous.
      #
      # @param incoming_message [ESM::Connection::Message] The incoming message
      # @param _outgoing_message [ESM::Connection::Message] The outgoing message
      #
      def on_response_sync(incoming_message, _outgoing_message)
        @mutex.synchronize { @incoming_message = incoming_message }
      end

      #
      # Used when a message needs to be treated like its synchronous.
      #
      # @param incoming_message [ESM::Connection::Message] The incoming message
      # @param _outgoing_message [ESM::Connection::Message] The outgoing message
      #
      def on_error_sync(incoming_message, _outgoing_message)
        @mutex.synchronize do
          @incoming_message = incoming_message
          @error = true
        end
      end
    end
  end
end
