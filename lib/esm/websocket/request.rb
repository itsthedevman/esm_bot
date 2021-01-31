# frozen_string_literal: true

module ESM
  class Websocket
    class Request
      include ESM::Callbacks

      attr_reader :id, :command_name, :parameters, :timeout, :metadata
      attr_accessor :response, :connection

      delegate :current_user, to: :@command, allow_nil: true

      # These callbacks correspond to events sent from the server.
      register_callbacks :before_execute, :after_execute
      add_callback :before_execute, :_before_execute

      def initialize(executing_command: nil, parameters: {}, timeout: 30, metadata: {})
        @id = SecureRandom.uuid
        @created_at = ::Time.now
        @metadata = metadata.deep_symbolize_keys
        @parameters = parameters
        @timeout = timeout || 30
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

      def handle_event(event_name, event_parameters)
        return if __callbacks.exclude?(event_name.to_sym)

        run_callback(event_name, @connection, event_parameters)
      end

      def acknowledged?
        @acknowledged
      end

      private

      def _before_execute(_connection, _parameters)
        @acknowledged = true
      end
    end
  end
end
