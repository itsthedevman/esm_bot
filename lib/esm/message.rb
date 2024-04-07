# frozen_string_literal: true

module ESM
  class Message
    include ESM::Callbacks

    #
    # Creates an instance of ESM::Message from JSON. See #to_h for the structure
    # @see #to_h
    #
    # @param json [String] The JSON to parse
    #
    # @return [Self]
    #
    def self.from_string(json)
      from_hash(json.to_h)
    end

    #
    # Creates a instance from a hash
    #
    # @param hash [Hash] The hash that contains the message contents
    #
    # @return [Self] The message
    #
    def self.from_hash(hash)
      hash = hash.deep_symbolize_keys

      message = new
      message = message.set_id(hash[:id]) if hash[:id].present?
      message = message.set_type(hash[:type]) if hash[:type].present?

      if hash[:data].present?
        message = message.set_data(hash.dig(:data, :type), hash.dig(:data, :content))
      end

      if hash[:metadata].present?
        message = message.set_metadata(hash.dig(:metadata, :type), hash.dig(:metadata, :content))
      end

      message = message.add_errors(hash[:errors]) if hash[:errors].present?
      message
    end

    attr_reader :id, :type, :errors

    # All callbacks are provided with two arguments:
    #   incoming_message [ESM::Message, nil]  The incoming message from the client, if applicable.
    #   outgoing_message [ESM::Message, nil]  The outgoing message sent through the server, if applicable.
    #
    # Available callbacks:
    #   on_response
    #     - Called when a message receives a response to its contents.
    #   on_error
    #     - Called when a message experienced an error.
    #     - There is a default implementation called "on_error". To use it, call `message.add_callback(:on_error, :on_error)`
    register_callbacks :on_response, :on_error

    # The driver of communication between the bot, server, and client. Rust is strict so this has to be too.
    # Any data and metadata must be configured in config/mapping.yml and defined in esm_message -> data.rs / metadata.rs
    # They will automatically be sanitized according to their data type as configured in the mapping.
    # NOTE: Invalid data/metadata attributes will be dropped!
    def initialize
      @id = SecureRandom.uuid
      @type = :event
      @data = Data.new
      @metadata = Metadata.new
      @errors = []
    end

    def set_id(id)
      @id = id
      self
    end

    def set_type(type)
      @type = type.to_sym
      self
    end

    # The primary data for this message. It's the good stuff.
    def set_data(type = @type, content = nil)
      @data = Data.new(type, content)
      self
    end

    #
    # Sets various values used by the arma mod and internally by Message::Error
    #
    # @param current_user [ESM::User, nil] The user that executed the command
    # @param target_user [ESM::User, ESM::User::Ephemeral, nil] The user who is the target of this command
    # @param server_id [String, nil] The server the command is being executed on
    #
    # @return [Message] A referenced to the modified message
    #
    def set_metadata(current_user: nil, target_user: nil, server_id: nil)
      metadata = {server_id:}

      if current_user
        metadata[:player] = Player.new(
          steam_uid: current_user.steam_uid,
          discord_id: current_user.discord_id,
          discord_name: current_user.username,
          discord_mention: current_user.mention
        )
      end

      if target_user
        target = {steam_uid: target_user.steam_uid}

        # Instances of User::Ephemeral do not contain discord information
        if !target_user.is_a?(ESM::User::Ephemeral)
          target.merge!(
            discord_id: target_user.discord_id,
            discord_name: target_user.username,
            discord_mention: target_user.mention
          )
        end

        metadata[:target] = Target.new(**target)
      end

      @metadata = Metadata.new(**metadata)
      self
    end

    # Each hash has the following attributes:
    #   type [Symbol, String] The type of error. Valid options are:
    #     code      # Uses the message to look up a predefined message in the locales
    #     message   # Treats the message like a string and sends it as is
    #   content [String] The content of this error.
    def add_errors(errors = [])
      return if !errors.respond_to?(:each)

      errors.each { |error| add_error(error[:type].to_s, error[:content]) }
      self
    end

    #
    # Adds the provided error to this message
    #
    # @param type [String] The error type. Valid types are: "code" and "message"
    # @param message [String] The message or code for this error
    #
    def add_error(type, content)
      return if type.nil? || content.nil?

      @errors << Error.new(self, type, content)
      self
    end

    def data_type
      @data.type
    end

    def data
      @data.content
    end

    def data_attributes
      @data.to_h
    end

    def metadata_type
      @metadata.type
    end

    def metadata
      @metadata.content
    end

    def metadata_attributes
      @metadata.to_h
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
    # @param for_arma [Boolean] Is this hash arma bound?
    #
    # @return [Hash] The message as a Hash. It has the following keys
    #   {
    #     id: The ID of this message as a UUID
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
      {
        id: id,
        type: type,
        data: data_attributes,
        metadata: metadata_attributes,
        errors: errors.map(&:to_h)
      }
    end

    #
    # Returns if there is any data on this message
    #
    # @return [Boolean]
    #
    def data?
      data.type && data.content
    end

    #
    # Returns if there is any metadata on this message
    #
    # @return [Boolean]
    #
    def errors?
      errors.any?
    end

    def inspect
      "#<ESM::Message #{JSON.pretty_generate(to_h)}>"
    end

    private

    def default_on_error(incoming_message)
      errors = (self.errors || []) + (incoming_message&.errors || [])
      errors.map! { |e| e.to_s(self) }.uniq!

      if command.nil?
        error!(errors: errors)
      else
        command.current_cooldown&.reset!

        embed = ESM::Embed.build(:error, description: errors.join("\n"))
        command.reply(embed)
      end
    end
  end
end
