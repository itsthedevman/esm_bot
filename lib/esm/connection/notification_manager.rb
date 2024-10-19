# frozen_string_literal: true

module ESM
  module Connection
    class NotificationManager
      PRACTICAL_MAX = 1 << 30

      def initialize(execution_interval: 0.5, batch_size: 50)
        @notifications_by_steam_uid = Concurrent::Map.new
        @steam_uids_for_processing = Concurrent::Set.new
        @batch_size = batch_size

        @task = Concurrent::TimerTask.execute(execution_interval:) { process_batch }
      end

      def add_batch(batch)
        batch.each do |notification|
          recipient_uid = notification.recipient_uid

          @notifications_by_steam_uid.compute(recipient_uid) do |notifications|
            (notifications || Concurrent::Array.new) << notification
          end

          @steam_uids_for_processing << recipient_uid
        end
      end

      private

      def process_batch
        batch = retrieve_batch

        batch.each do |notification|

        end
      end

      def retrieve_batch
        batch = []

        # Retrieve a batch with minimal amount of mutex holding if possible, I think
        @steam_uids_for_processing.delete_if do |steam_uid|
          # This is doing some heavy lifting, imo
          # I'm balancing holding a mutex and ensuring a notification isn't accidentally dropped
          # if I used #clear, for example.
          batch += @notifications_by_steam_uid[steam_uid].shift(PRACTICAL_MAX)

          # The batch size is more of a "soft" limit
          batch.size < @batch_size
        end

        batch
      end

      def send_to_users(embed)
        # Get the preferences for all the users we're supposed to send to
        dm_preferences_by_user_id = ESM::UserNotificationPreference.where(
          user_id: @users.pluck(:id)
        ).pluck(
          :user_id, @xm8_type.underscore
        ).to_h

        # Default the preference to allow. This is used for if the user hasn't ran the preference command before
        dm_preferences_by_user_id.default = true

        @users.each do |user|
          dm_allowed = dm_preferences_by_user_id[user.id]
          next unless dm_allowed

          pending_delivery = ESM.bot.deliver(embed, to: user.discord_user, async: false)
          message = pending_delivery&.wait_for_delivery
        end
      end

      def send_to_custom_routes(embed)
        # Custom routes are a little different.
        #   Using a mention in an embed does not cause a "notification" on discord.
        #     This does not work since these are often urgent.
        #   To get around this, routes need to be grouped by channel.
        #   From here, an initial message can be sent tagging each user with this channel (and type)
        users_by_channel_id = ESM::UserNotificationRoute.select(:user_id, :channel_id)
          .includes(:user)
          .enabled
          .accepted
          .where(notification_type: @xm8_type, user_id: @users.pluck(:id))
          .where("source_server_id IS NULL OR source_server_id = ?", @server.id)
          .group_by(&:channel_id)
          .transform_values! { |r| r.map(&:user) }

        users_by_channel_id.each do |channel_id, users|
          pending_delivery = ESM.bot.deliver(
            embed,
            to: channel_id,
            embed_message: "#{@xm8_type.titleize} - #{users.map(&:mention).join(" ")}",
            async: false
          )
          notification_message = pending_delivery&.wait_for_delivery
        end
      end
    end
  end
end
