# frozen_string_literal: true

module ESM
  class Bot
    class ReplyOverseer
      def initialize(bot)
        @bot = bot
        @entries = {}

        check_every = ESM.config.loops.bot_reply_overseer.check_every
        @thread = Thread.new do
          loop do
            check_entries
            sleep(ESM.env.test? ? 0.5 : check_every)
          end
        end
      end

      #
      # Waits for an event from user_id and channel_id. Once the message event is received, it will execute the callback
      #
      # @param user_id [Integer/String] The ID of the user who sends the message
      # @param channel_id [Integer/String] The ID of the channel where the message is sent to. The bot must be a member of said channel
      # @param expires_at [DateTime, Time] When this time is reached, the callback will be called with `nil` for the event
      # @param &callback [Proc] The code to execute once the message has been received
      #
      # @return [true]
      #
      def watch(user_id:, channel_id:, expires_at: 5.minutes.from_now, &callback)
        @entries[user_id.to_s] ||= {}
        @entries[user_id.to_s][channel_id] = { callback: callback, expires_at: expires_at }

        true
      end

      #
      # Returns if the overseer is watching for user_id to send a message in channel_id
      #
      # @param user_id [Integer/String] The ID of the user who sends the message
      # @param channel_id [Integer/String] The ID of the channel where the message is sent to.
      #
      # @return [Boolean]
      #
      def watching?(user_id:, channel_id:)
        @entries[user_id].key?(channel_id)
      end

      #
      # Called when the bot receives a message
      #
      # @param event [Discordrb::Command::CommandEvent] The incoming event
      #
      def on_message(event)
        entry = @entries[event.user.id.to_s].try(:delete, event.channel.id.to_s)
        return if entry.nil? || entry[:callback].nil?

        # Call the registered code
        entry[:callback].call(event)
      end

      private

      def check_entries
        @entries.each do |_user_id, channel_ids|
          channel_ids.each do |channel_id, entry|
            next if entry[:expires_at] > ::Time.now

            channel_ids.delete(channel_id)
            entry[:callback].call(nil)
          end
        end
      end
    end
  end
end
