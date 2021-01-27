# frozen_string_literal: true

module ESM
  class Websocket
    class Request
      attr_reader :id, :command_name, :parameters, :timeout, :metadata, :remove_on_acknowledge
      attr_accessor :response, :connection

      delegate :current_user, to: :@command, allow_nil: true

      def initialize(executing_command: nil, parameters: {}, timeout: 30, metadata: {}, remove_on_acknowledge: false)
        @id = SecureRandom.uuid
        @created_at = ::Time.now
        @metadata = metadata.deep_symbolize_keys
        @parameters = parameters
        @timeout = timeout || 30
        @remove_on_acknowledge = remove_on_acknowledge
        @acknowledged = false
        @command = nil

        if executing_command.present? && executing_command.is_a?(ESM::Command::Base)
          @command = executing_command
          @command_name = executing_command.name

          # If this request was triggered by a user, set their data so its accessible on the server
          if executing_command.current_user.present?
            user = executing_command.current_user
            @metadata[:user_id] ||= user.id
            @metadata[:user_name] ||= user.username
            @metadata[:user_mention] ||= user.mention
            @metadata[:user_steam_uid] ||= user.steam_uid
          end
        else
          # executing_command is now a string
          @command_name = executing_command
        end
      end

      def to_h
        {
          id: @id,
          command_name: @command_name,
          parameters: @parameters,
          metadata: @metadata
        }
      end

      def to_s
        to_h.to_json
      end

      def timed_out?
        (::Time.now - @created_at) >= @timeout
      end

      def on_acknowledgement=(callback)
        @on_acknowledgement_callback = callback
      end

      def on_acknowledgement
        @on_acknowledgement.call(@connection) if defined?(@on_acknowledgement)
      end

      def acknowledge
        @acknowledged = true

        # Trigger the callback
        on_acknowledgement

        # Remove the request if requested
        @connection.remove_request(@id) if @remove_on_acknowledge
      end

      def acknowledged?
        @acknowledged
      end
    end
  end
end
