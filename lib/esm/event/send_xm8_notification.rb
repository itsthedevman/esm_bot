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
        notifications, unregistered_notifications = separate_notifications_by_registration

        # Update the server's database
        update_unregistered_notifications(unregistered_notifications) if unregistered_notifications
        return unless notifications.size > 0

        Connection::NotificationManager.
      end

      private

      def separate_notifications_by_registration
        # To keep the network traffic down, a single notification can have one or more recipients
        notifications =
          message.data.notifications.filter_map do |n|
            Xm8Notification.from(n)
          rescue Xm8Notification::InvalidType
            notify_invalid_notification!(n, :invalid_type)
            nil
          rescue Xm8Notification::InvalidContent
            notify_invalid_notification!(n, :invalid_attributes)
            nil
          end

        registered_uids =
          User.where(
            steam_uid: notifications.flat_map(&:recipient_uids)
          ).pluck(:steam_uid)

        unregistered_notifications = []
        notifications.select! do |notification|
          unregistered = notification.reject_unregistered_uids!(registered_uids)
          unregistered_notifications += unregistered if unregistered.size > 0

          notification.recipient_uids.size > 0
        end

        [notifications, unregistered_notifications]
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
