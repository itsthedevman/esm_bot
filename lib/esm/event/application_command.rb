# frozen_string_literal: true

module ESM
  module Event
    #
    # Delegator over Discordrb::Events::ApplicationCommandEvent
    #
    class ApplicationCommand
      # All of these track if a command is currently in progress for a user.
      # This keeps a user from running a blocking command multiple times and potentially
      # causing unexpected behaviors
      class << self
        # @!visibility private
        def in_progress
          @in_progress ||= Concurrent::Map.new { |h, k| h[k] = Concurrent::Set.new }
        end

        # @!visibility private
        def in_progress?(class_name, user_discord_id)
          in_progress[class_name].include?(user_discord_id)
        end

        # @!visibility private
        def in_progress!(class_name, user_discord_id)
          in_progress[class_name].add(user_discord_id)
        end

        # @!visibility private
        def completed!(class_name, user_discord_id)
          in_progress[class_name].delete(user_discord_id)
        end
      end

      delegate :user, :channel, :options, :respond, :edit_response, :delete_response, to: :@event

      def initialize(event)
        @event = event

        @tip_key = "tip_counter"
        @tip = ESM.config.tips.sample

        @embed_template =
          ESM::Embed.build do |e|
            e.color = Color::BLUE
          end

        @backtrace_cleaner = ActiveSupport::BacktraceCleaner.new
        @backtrace_cleaner.add_filter { |line| line.gsub(ESM.root.to_s, "").delete_prefix("/") }
        @backtrace_cleaner.add_silencer { |line| /gems/.match?(line) }
      end

      #
      # Discordrb's ApplicationCommandEvent code does not appear to handle if there
      # is no server_id, which causes a crash
      #
      def server
        return if @event.server_id.nil?

        @event.server
      end

      def on_execution(command_class)
        respond(content: "Processing your request...")

        @command = command_class.new(user:, server:, channel:, arguments: options)

        check_for_in_progress!
        command_in_progress!

        ESM::Database.with_connection do
          @command.from_discord!
        end

        on_completion
      rescue => error
        on_error(error)
      ensure
        command_completed!
      end

      def on_completion
        content = ":stopwatch: Completed in #{@command.timers.humanized_total}"
        content = add_tip(content)

        edit_response(content: content)

        @command
      end

      def on_error(error)
        return delete_response if error.is_a?(Exception::CheckFailureNoMessage)

        content =
          if error.is_a?(Exception::ApplicationError)
            ":warning: I was unable to complete your request :warning:\n"
          else
            ":grimacing: Well, this is awkward... :grimacing:\n"
          end

        edit_response(content:)

        message =
          case error
          when ESM::Exception::RequestTimeout
            ESM::Embed.build(
              :error,
              description: I18n.t(
                "exceptions.extension.message_undeliverable",
                user: @command.current_user.mention,
                server_id: @command.target_server.server_id
              )
            )
          when ESM::Exception::ApplicationError
            error.data
          else # when StandardError
            uuid = SecureRandom.uuid.split("-")[0..1].join("")

            ESM.bot.log_error(
              uuid:,
              user: @command.current_user.attributes_for_logging,
              message: error.inspect,
              backtrace: @backtrace_cleaner.clean(error.backtrace)
            )

            ESM::Embed.build(:error, description: I18n.t("exceptions.system", error_code: uuid))
          end

        ESM.bot.deliver(message, to: @command.current_channel)

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

      def add_tip(content)
        return content unless send_tip?

        content + "\n\n:information_source: **Did you know?**\n#{@tip}"
      end

      def check_for_in_progress!
        user = @command.current_user
        return unless self.class.in_progress?(@command.class, user.discord_id)

        raise Exception::CommandInProgress, Embed.build(
          :error,
          description: I18n.t("command_errors.command_in_progress", user: user.mention)
        )
      end

      def command_in_progress!
        self.class.in_progress!(@command.class, @command.current_user.discord_id)
      end

      def command_completed!
        self.class.completed!(@command.class, @command.current_user.discord_id)
      end
    end
  end
end
