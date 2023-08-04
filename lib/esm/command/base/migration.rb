# frozen_string_literal: true

#
# This entire file is dedicated to the migration methods from @esm v1 to @esm v2
# This file will be deleted once the migration has been completed
#
module ESM
  module Command
    class Base
      # V1
      module Migration
        extend ActiveSupport::Concern

        class_methods do
          def v2_variant!
            self.has_v1_variant = true
          end

          def v1_variant?
            !!has_v1_variant
          end

          def as_v1_variant
            ESM::Command.get_v1(self.class.command_name).new(**arguments)
          end
        end

        # V1
        # @deprecated Use on_execute instead
        def discord
        end

        # V1
        # @deprecated Use on_response instead
        def server
        end

        #
        # V1: This is called when the message is received from the server
        #
        def from_server
          parameters = event

          # Parameters is always an array. 90% of the time, parameters size will only be 1
          # This just makes typing a little easier when writing commands
          @response = (parameters.size == 1) ? parameters.first : parameters

          # Trigger the callback
          on_response(nil, nil)
        end

        # Raises an exception of the given class or ESM::Exception::CheckFailure.
        # If a block is given, the return of that block will be message to raise
        # Otherwise, it will build an error embed
        #
        # @deprecated
        # @see #raise_error!
        def check_failed!(name = nil, **args, &block)
          message =
            if block
              yield
            elsif name.present?
              ESM::Embed.build(:error, description: I18n.t("command_errors.#{name}", **args.except(:exception_class)))
            end

          # Logging
          # This is triggered by system commands as well
          if event
            warn!(
              author: "#{current_user.distinct} (#{current_user.discord_id})",
              channel: "#{Discordrb::Channel::TYPE_NAMES[current_channel.type]} (#{current_channel.id})",
              reason: message.is_a?(Embed) ? message.description : message,
              command: to_h
            )
          end

          raise args[:exception_class] || ESM::Exception::CheckFailure, message
        end

        # V1: Send a request to the DLL
        #
        # @param command_name [String, nil] V1: The name of the command to send to the DLL. Default: self.name.
        def deliver!(command_name: nil, timeout: 30, **parameters)
          raise ESM::Exception::CheckFailure, "Command does not have an associated server" if target_server.nil?

          # Build the request
          request =
            ESM::Websocket::Request.new(
              command: self,
              command_name: command_name,
              user: current_user,
              channel: current_channel,
              parameters: parameters,
              timeout: timeout
            )

          # Send it to the dll
          ESM::Websocket.deliver!(target_server.server_id, request)
        end

        def v2_target_server?
          !!target_server&.v2?
        end

        def v2?
          !name.ends_with?("_v1")
        end
      end
    end
  end
end
