# frozen_string_literal: true

module ESM
  module Event
    #
    # Delegator over Discordrb::Events::ApplicationCommandEvent
    #
    class ApplicationCommand
      delegate :user, :channel, :options, :respond, :edit_response, :delete_response, to: :@event

      def initialize(event)
        @event = event

        @tip_key = "tip_counter"
        @tip = ESM.config.tips.sample

        @embed_template =
          ESM::Embed.build do |e|
            e.color = Color::BLUE
          end
      end

      #
      # Discordrb's ApplicationCommandEvent code does not appear to handle if there is no server_id and crashes
      #
      def server
        return if @event.server_id.nil?

        @event.server
      end

      def on_execution(command_class)
        @command = command_class.new(user: user, server: server, channel: channel, arguments: options)

        embed = @embed_template.tap do |e|
          e.description = "Processing your request..."
        end

        respond(embeds: [embed.for_discord_embed])

        @command.from_discord!

        on_completion
      rescue => error
        on_error(error)
      end

      def on_completion
        embed = @embed_template.tap do |e|
          e.description = ":stopwatch: Completed in #{@command.timers.humanized_total}"

          add_tip(e)
          add_usage(e)
        end

        edit_response(embeds: [embed.for_discord_embed])

        @command
      end

      private

      def on_error(error)
        return delete_response if error.is_a?(Exception::CheckFailureNoMessage)

        message =
          case error
          when ESM::Exception::CheckFailure
            error.data
          when StandardError
            uuid = SecureRandom.uuid.split("-")[0..1].join("")

            ESM.bot.log_error(uuid: uuid, message: error.message, backtrace: error.backtrace)

            ESM::Embed.build(:error, description: I18n.t("exceptions.system", error_code: uuid))
          end

        ESM.bot.deliver(message, to: channel)

        embed = @embed_template.tap do |e|
          e.color = Color::RED

          if error.is_a?(Exception::CheckFailure)
            e.title = ":warning: I was unable to complete your request :warning:"
            e.description = ""
          else
            e.title = ":grimacing: Well, this is awkward... :grimacing:"
            e.description = ":bangbang: An error occurred :bangbang:"
          end

          add_usage(e)
        end

        edit_response(embeds: [embed.for_discord_embed])

        @command
      end

      def send_tip?
        @send_tip ||= lambda do
          counter = ESM.cache.increment(@tip_key)
          send_tip = counter > (1 + (1 + rand + rand).round)

          ESM.cache.delete(@tip_key) if send_tip # Reset the counter

          send_tip
        end.call
      end

      def add_tip(e)
        return unless send_tip?

        e.add_field(name: ":information_source: Did you know?", value: "*#{@tip}*")
      end

      def add_usage(e)
        e.description += "\n\n*Click below to view full command:* ||```#{@command.usage}```||"
      end
    end
  end
end
