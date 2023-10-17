# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Lifecycle
        extend ActiveSupport::Concern

        class_methods do
          #
          # The entry point of a command
          # This is registered with Discordrb and is called as part of an interaction lifecycle
          #
          # @note This method will gracefully handle 99% of the errors automatically.
          # I recommend avoiding manually handling exceptions in a command's lifecycle so this system can handle it. But the choice is up to you
          #
          # @!visibility private
          #
          def event_hook(event)
            error = false

            # Shows "Exile Server Manager is thinking...". This is so much better than "typing"
            event.defer(ephemeral: false)

            command = new(**event.options.symbolize_keys)
            command.execute(ESM::Event::ApplicationCommand.new(event))
          rescue => e
            # This occurs if event.defer fails due to Discord dropping the interaction before the bot had a chance to process it
            return if command.nil?

            error = true
            command.handle_error(e)
          ensure
            # Ugh - can't guard here
            if !command.nil?
              content =
                if error
                  "Well, this is awkward..."
                else
                  "Completed in #{command.timers.from_discord.time_elapsed.round} seconds"
                end

              event.edit_response(content: content)
            end
          end
        end

        def execute(event)
          @event = event

          if event.is_a?(ESM::Event::ApplicationCommand)
            timers.time!(:from_discord) do
              from_discord
            end
          else
            # V1
            timers.time!(:from_server) do
              from_server
            end
          end

          self
        end

        #
        # Called internally by #execute, this method handles when a command has been executed on Discord.
        #
        def from_discord
          # Check for these BEFORE validating the arguments so even if an argument was invalid, it doesn't matter since these take priority
          check_for_text_only!
          check_for_dm_only!
          check_for_player_mode!
          check_for_permissions!

          # Now ensure the user hasn't smoked too much lead
          arguments.validate!

          # Adding a comment to make this look better is always a weird idea
          info!(to_h)

          # Finish up the checks
          check_for_dev_only!
          check_for_registered!
          check_for_nil_target_server! unless skipped_actions.nil_target_server?
          check_for_nil_target_community! unless skipped_actions.nil_target_community?
          check_for_nil_target_user! unless skipped_actions.nil_target_user?
          check_for_different_community! unless skipped_actions.different_community?
          check_for_cooldown! unless skipped_actions.cooldown?
          check_for_connected_server! unless skipped_actions.connected_server?

          # Now execute the command
          result = nil
          timers.time!(:on_execute) do
            load_v1_code! if v1_code_needed? # V1

            result = on_execute
          end

          # Update the cooldown after the command has ran just in case there are issues
          create_or_update_cooldown unless skipped_actions.cooldown?

          # This just tracks how many times a command is used
          ESM::CommandCount.increment_execution_counter(name)

          result
        end

        # @param request [ESM::Request] The request to build this command with
        # @note Don't load `target_user` from the request. If the arguments contain a target, it will handle it
        def from_request(request)
          @request = request
          @current_channel = ESM.bot.channel(request.requested_from_channel_id)
          @current_user = request.requestor.discord_user

          # Initialize our command from the request
          arguments.merge!(request.command_arguments.symbolize_keys) if request.command_arguments.present?

          timers.time!(:from_request) do
            load_v1_code! if v1_code_needed? # V1

            if @request.accepted
              request_accepted
            else
              # Reset the cooldown since the request was declined.
              current_cooldown.reset! if current_cooldown.present?

              request_declined
            end
          end
        end

        def on_execute
        end

        def on_response(_incoming_message, _outgoing_message)
        end

        def request_accepted
        end

        def request_declined
        end

        def handle_error(error)
          return self if error.is_a?(ESM::Exception::CheckFailureNoMessage)

          message =
            case error
            when ESM::Exception::CheckFailure
              error.data
            when StandardError
              uuid = SecureRandom.uuid.split("-")[0..1].join("")
              error!(uuid: uuid, message: error.message, backtrace: error.backtrace)

              ESM::Embed.build(
                :error,
                description: I18n.t("exceptions.system", error_code: uuid)
              )
            end

          reply(message)

          self
        end
      end
    end
  end
end
