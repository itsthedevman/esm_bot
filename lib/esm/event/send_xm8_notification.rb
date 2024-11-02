# frozen_string_literal: true

module ESM
  module Event
    class SendXm8Notification
      attr_reader :server, :community, :message

      def initialize(server, message)
        @server = server
        @community = server.community
        @message = message
      end

      def run!
        notifications = filter_notifications
        return if notifications.blank?

        Connection::NotificationManager.add(notifications)
      end

      private

      def filter_notifications
        notifications =
          filter_unregistered_recipients(message.data.notifications)

        notifications.map do |notification|
          Xm8Notification.from(notification)
        rescue Xm8Notification::InvalidType
          notify_invalid_notification!(n, :invalid_type)
        rescue Xm8Notification::InvalidContent
          notify_invalid_notification!(n, :invalid_attributes)
        end
      end

      def filter_unregistered_recipients(notifications)
        uid_to_user_mapping = User.where(steam_uid: recipient_steam_uids)
          .pluck(:steam_uid, :user_id)
          .to_h

        notifications_to_send = []
        notifications_to_reject = []

        notifications.each do |notification|
          recipient_notification_mapping = {}

          # These two attributes are index linked, meaning index 0 in both arrays are related
          recipients = notification[:recipient_uids].zip(notification[:uuids])

          # Remove any unregistered UIDs, and store the associated UUID
          recipients.each do |uid, uuid|
            user = uid_to_user_mapping[uid]
            next notifications_to_reject << uuid if user.nil?

            recipient_notification_mapping[user] = uuid
          end

          next if recipient_notification_mapping.blank?

          notification[:server] = server
          notification[:recipient_notification_mapping] = recipient_notification_mapping

          notifications_to_send << notification
        end

        # Update the server's database to stop sending these
        if notifications_to_reject.size > 0
          update_unregistered_notifications(notifications_to_reject)
        end

        notifications_to_send
      end

      def notify_invalid_notification!(notification, type)
        embed =
          ESM::Embed.build do |e|
            e.title = I18n.t(
              "xm8_notifications.#{type}.title",
              server: server.server_id
            )

            e.description = I18n.t(
              "xm8_notifications.#{type}.description",
              type: notification[:type]
            )

            e.add_field(
              name: I18n.t(:xm8_notification),
              value: "```#{JSON.pretty_generate(notification)}```"
            )

            e.color = :red
            e.footer = I18n.t("xm8_notifications.footer")
          end

        server.community.log_event(:xm8, embed)
      end

      def update_unregistered_notifications(unregistered_notifications)
        status_update = unregistered_notifications.to_h do |uuid|
          [uuid, Xm8Notification::STATUS_NOT_REGISTERED]
        end

        message = ESM::Message.new
          .set_type(:query)
          .set_data(
            query_function_name: "update_xm8_notification_status",
            **status_update
          )

        server.send_message(message, block: false)
      end
    end
  end
end
