# frozen_string_literal: true

module ESM
  module Event
    class SendXm8Notification
      attr_reader :server, :community, :notifications

      def initialize(server, message)
        @server = server
        @community = server.community

        @notifications = message.data.notifications.filter_map do |n|
          Xm8Notification.from(n)
        rescue Xm8Notification::InvalidType
          notify_invalid_notification!(n, :invalid_type)
          nil
        rescue Xm8Notification::InvalidContent
          notify_invalid_notification!(n, :invalid_attributes)
          nil
        end
      end

      def run!
      end

      private

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
    end
  end
end
