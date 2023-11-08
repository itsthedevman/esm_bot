# frozen_string_literal: true

module ESM
  module Event
    #
    # Delegator over Discordrb::Events::ApplicationCommandEvent
    #
    class ApplicationCommand < SimpleDelegator
      def initialize(...)
        super(...)

        @hint_key = "hint_counter"
      end

      #
      # Discordrb's ApplicationCommandEvent code does not appear to handle if there is no server_id and crashes
      #
      def server
        return if server_id.nil?

        __getobj__.server
      end

      def on_completion(command)
        time_to_complete = "Completed in #{command.timers.humanized_total}"

        if send_hint?
          ESM.cache.delete(@hint_key) # Reset the counter

          edit_response(content: time_to_complete + "\n:information_source: #{ESM.config.hints.sample}")
        else
          edit_response(content: time_to_complete)
        end
      end

      def on_error(error)
        return if error.is_a?(ESM::Exception::CheckFailureNoMessage)

        message =
          case error
          when ESM::Exception::CheckFailure
            error.data
          when StandardError
            uuid = SecureRandom.uuid.split("-")[0..1].join("")
            error!(uuid: uuid, message: error.message, backtrace: error.backtrace)

            ESM::Embed.build(
              :error,
              title: "Well, this is awkward...",
              description: I18n.t("exceptions.system", error_code: uuid)
            )
          end

        if message.is_a?(ESM::Embed)
          edit_response(embeds: [message.for_discord_embed])
        else
          edit_response(content: message)
        end
      end

      private

      def send_hint?
        counter = ESM.cache.increment(@hint_key)
        counter > (1 + (1 + rand + rand).round)
      end
    end
  end
end
