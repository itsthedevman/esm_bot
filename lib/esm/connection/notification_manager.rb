# frozen_string_literal: true

module ESM
  module Connection
    class NotificationManager
      include Singleton

      attr_reader :queue

      def self.add(notifications)
        notifications.each { |n| instance.queue.push(n) }
      end

      def initialize(execution_interval: 0.5)
        @queue = Queue.new
        @task = Concurrent::TimerTask.execute(execution_interval:) { process_next }
      end

      private

      def process_next
        notification = @queue.pop(timeout: 0)
        return if notification.nil?

        users = notification.users.select_for_xm8_notifications
        data = {
          notification:,
          users:,
          user_ids: users.map(&:id), # No pluck, that fires a query
          embed: notification.to_embed
        }

        status_update = send_to_users(**data)
        status_update.merge!(send_to_custom_routes(**data))
      end

      def send_to_users(notification:, users:, user_ids:, embed:)
        dm_preferences_by_user_id = ESM::UserNotificationPreference.where(user_id: user_ids)
          .pluck(:user_id, notification.type.underscore)
          .to_h

        # Default the preference to allow.
        # This is needed if the user hasn't ran the preference command before
        dm_preferences_by_user_id.default = true

        users.each do |user|
          dm_allowed = dm_preferences_by_user_id[user.id]
          next unless dm_allowed

          message = ESM.bot.deliver(embed, to: user.discord_user, block: true)
          # TODO: Update status on server
        end
      end

      def send_to_custom_routes(notification:, users:, user_ids:, embed:)
        user_lookup = users.to_h { |u| [u.id, u] }

        # Custom routes are a little different.
        #   Using a mention in an embed does not cause a "notification" on discord.
        #     This does not work since these are often urgent.
        #   To get around this, routes need to be grouped by channel.
        #   From here, an initial message can be sent tagging each user with this channel (and type)
        users_by_channel_id = ESM::UserNotificationRoute.select(:user_id, :channel_id)
          .enabled
          .accepted
          .where(notification_type: notification.type, user_id: user_ids)
          .where("source_server_id IS NULL OR source_server_id = ?", notification.server.id)
          .group_by(&:channel_id)

        users_by_channel_id.each do |channel_id, routes|
          users = routes.map { |route| user_lookup[route.user_id] }

          notification_message = ESM.bot.deliver(
            embed,
            to: channel_id,
            embed_message: "#{notification.type.titleize} - #{users.map(&:mention).join(" ")}",
            block: true
          )
          # TODO: Update status on server
        end
      end
    end
  end
end
