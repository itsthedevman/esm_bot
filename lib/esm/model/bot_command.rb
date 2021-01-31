# frozen_string_literal: true

module ESM
  class BotCommand
    WHITELISTED_SERVER_COMMANDS = %w[
      server_initialization
      xm8_notification
      discord_log
      discord_message_channel
    ].freeze

    def initialize(connection:, received_data:)
      @connection = connection
      @data = received_data
      @error_message = nil
      normalize_parameters

      ESM.logger.debug("#{self.class}##{__method__}") do
        JSON.pretty_generate(
          server_id: connection.server.server_id,
          data: self.to_h
        )
      end
    end

    # V1 commandID
    # id is 2.0.0
    def id
      @data.commandID.presence || @data.id
    end

    # V1 command
    # command_name is 2.0.0
    def name
      @data.command.presence || @data.command_name
    end

    def parameters
      @parameters ||= lambda do
        parameters = @data.parameters
        return parameters if parameters.is_a?(Array) || parameters.is_a?(OpenStruct)

        parameters.to_ostruct
      end.call
    end

    # Used when a command was sent to the arma server, the code would send back a command with one of these set
    # V1: #ignore, #returned
    def disregard?
      @data.ignore || @data.returned || false
    end

    def error?
      @error_message.presence || false
    end

    # Checks if the request should be removed on the first ignore
    def remove_on_disregard?
      request ? request.remove_on_ignore : false
    end

    def error_message
      @error_message ||= lambda do
        # V1 errors from the DLL
        return @data.error if @data.error.present?

        # V1 errors from the SQF
        return self.parameters.first.error if self.parameters.is_a?(Array) && self.parameters&.first&.error&.present?

        # This is how 2.0.0 handles errors
        self.parameters.error_message
      end.call
    end

    def request
      @request ||= lambda do
        request = @connection.requests[self.id]
        request.connection = @connection
        request
      end.call
    end

    def execute!
      # V2 only. The server has sent over an event request, attempt to run any callbacks
      return request.handle_event(parameters._event, parameters._event_parameters) if request && parameters._event.present?

      # V1 only. Checks if the request should be processed
      if disregard?
        remove_request if remove_on_disregard?
        return
      end

      # Reload the server so our data is fresh
      @connection.server.reload

      # Process the request
      if request.present? && ESM::Command.include?(self.name)
        process_command_response
      elsif WHITELISTED_SERVER_COMMANDS.include?(self.name)
        process_server_command
      else
        # Invalid command call. Log it!
        ESM.logger.warn("#{self.class}##{__method__}") do
          JSON.pretty_generate(server_id: @connection.server.id, command: self.to_h, request: request.to_h)
        end
      end
    end

    def to_h
      {
        id: self.id,
        command_name: self.name,
        parameters: self.parameters.to_h,
        disregard: self.disregard?,
        error: self.error_message
      }
    end

    # Removes the request from the queue if present
    def remove_request
      @connection.remove_request(self.id) if request
    end

    private

    # Processes a command response from the A3 server.
    def process_command_response
      # Logging
      ESM::Notifications.trigger("command_from_server", received_command: self)

      # We have an error from the DLL
      raise ESM::Exception::CheckFailure, self.error_message if self.error?

      # Execute the command
      request.command.execute(self.parameters)
    rescue ESM::Exception::CheckFailure => e
      # This catches if the server reported that the command failed
      on_command_error
    ensure
      # Make sure to remove the request no matter what
      remove_request
    end

    # Processes server command that doesn't come from a request.
    def process_server_command
      # Build the class and call it
      "ESM::Event::#{self.name.classify}".constantize.new(
        connection: @connection,
        server: @connection.server,
        parameters: self.parameters.is_a?(Array) ? self.parameters.first : self.parameters
      ).run!
    end

    # Goes over every item in the parameters and checks to see if an item needs converted to a hash
    # The normalization process follows these rules:
    #   Rule 1: Data can be an Array of any combination of the following: String, Scalar, Boolean, Array, or Hash (Defined as an array of pairs, with the first item being a string in all entries)
    #   Rule 2: To define a hash, create an array of pairs. Each pair must have a String as the first item and a valid JSON type as the second. This array cannot contain any other forms of items, otherwise it will be treated like an array. For example: [ [key1, value], [key2, value] ] -> { key1: value, key2: value }
    #   Rule 3: To define an Array, create an array of values. This will be converted as an array so long as all of the items in the array is not set up like Rule 2.
    #   Rule 4: To define an Array of hashes, create an array of array pairs. For example: [ [ [key, value] ], [ [ key, value], [key2, value] ] ] -> [{ key: value }, { key: value, key2: value }]
    def normalize_parameters
      normalized_inputs = normalize_input(parameters)

      # Normalize to an OpenStruct
      @parameters =
        if normalized_inputs.is_a?(Array)
          normalized_inputs.map(&:to_ostruct)
        else
          normalized_inputs.to_ostruct
        end
    end

    # The parameters sent over by Arma can be in a SimpleArray format. This will convert the value if need be.
    # Parameters can be of type: Array, OpenStruct, and any valid json type (the array and OpenStruct are the important ones)
    def normalize_input(input)
      # The ending result of the sanitization
      sanitized_input = input

      # OpenStructs and Array pairs both respond to `to_h` and go through the same process
      if input.is_a?(OpenStruct) || (input.is_a?(Array) && valid_array_hash?(input))
        sanitized_input = input.to_h

        # Checks and converts the each item in the Hash/OpenStruct if needed
        sanitized_input.each do |key, value|
          sanitized_input[key] = normalize_input(value)
        end
      else
        # Integer, String, boolean, what have you
        return sanitized_input if !sanitized_input.is_a?(Array)

        # Checks and converts the each item in the array if needed
        sanitized_input.each_with_index do |value, index|
          sanitized_input[index] = normalize_input(value)
        end
      end

      sanitized_input
    end

    # Checks if the array is set up to be able to be converted to a hash
    def valid_array_hash?(input)
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
        JSON.pretty_generate(command: self.to_h, duplicated_keys: duplicates)
      end

      # There were duplicates found but the input will still be marked valid since it can be converted
      true
    end

    # Reports the error back to the user so they know the command failed
    def on_command_error(error)
      return if request.current_user.nil?

      # Reset the current cooldown
      request.command.current_cooldown.reset!

      # V1: Some errors from the dll already have a mention in them...
      error = "#{request.current_user.mention}, #{error}" if !error.start_with?("<")

      # Send the error message
      embed = ESM::Embed.build(:error, description: error)
      request.command.reply(embed)
    end
  end
end
