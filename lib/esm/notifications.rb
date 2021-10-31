# frozen_string_literal: true

module ESM
  class Notifications
    EVENTS = %w[
      debug
      info
      warn
      error
      ready
      argument_parse
      server_on_connect
      websocket_server_on_close
      websocket_server_deliver
      command_from_discord
      command_from_server
      command_check_failed
      bot_deliver
      bot_resend_queue
      websocket_client_on_message
      xm8_notification_invalid_type
      xm8_notification_invalid_attributes
      xm8_notification_on_send
    ].freeze

    def self.trigger(name, **args)
      raise ESM::Exception::Error, "#{name} is not a whitelisted notification event" if !EVENTS.include?(name)

      ActiveSupport::Notifications.instrument("#{name}.esm", args)
    rescue StandardError => e
      ESM.logger.error("#{self.class}##{__method__}") { ESM::JSON.pretty_generate(uuid: SecureRandom.uuid, message: e.message, backtrace: e.backtrace) }
    end

    def self.subscribe
      EVENTS.each do |event|
        ActiveSupport::Notifications.subscribe("#{event}.esm", &method(event))
      end
    end

    ["debug", "info", "warn", "error"].each do |sev|
      define_singleton_method(sev) do |name, _start, _finish, _id, payload|
        if payload[:error].is_a?(StandardError)
          e = payload[:error].dup

          payload[:error] = {
            message: e.message,
            backtrace: e.backtrace[0..20]
          }
        end

        if payload.key?(:class) && payload.key?(:method)
          name = "#{payload[:class]}##{payload[:method]}"

          payload.delete(:class)
          payload.delete(:method)
        end

        ESM.logger.send(sev.to_sym, name) do
          ESM::JSON.pretty_generate(payload)
        end
      end
    end

    def self.ready(name, _start, _finish, _id, _payload)
      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(
          invite_url: ESM.bot.invite_url(permission_bits: ESM::Bot::PERMISSION_BITS)
        )
      end
    end

    def self.command_from_discord(name, _start, _finish, _id, payload)
      command = payload[:command]

      # This is triggered by system commands as well
      return if command.event.nil?

      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(
          author: "#{command.current_user.distinct} (#{command.current_user.id})",
          channel: "#{Discordrb::Channel::TYPE_NAMES[command.event.channel.type]} (#{command.event.channel.id})",
          command: command.name,
          message: command.event.message.content,
          arguments: command.arguments.to_h,
          cooldown: command.current_cooldown&.attributes
        )
      end
    end

    def self.command_check_failed(name, _start, _finish, _id, payload)
      command = payload[:command]
      reason = payload[:reason]

      # This is triggered by system commands as well
      return if command.event.nil?

      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(
          author: "#{command.current_user.distinct} (#{command.current_user.id})",
          channel: "#{Discordrb::Channel::TYPE_NAMES[command.event.channel.type]} (#{command.event.channel.id})",
          command: command.name,
          message: command.event.message.content,
          arguments: command.arguments.to_h,
          reason: reason.is_a?(Embed) ? reason.description : reason
        )
      end
    end

    def self.command_from_server(name, _start, _finish, _id, payload)
      command = payload[:command]

      # This is triggered by system commands as well
      return if command.nil?
      return if command.event.nil?

      ESM.logger.info(name) do
        JSON.pretty_generate(
          author: "#{command.current_user.distinct} (#{command.current_user.id})",
          channel: "#{Discordrb::Channel::TYPE_NAMES[command.event.channel.type]} (#{command.event.channel.id})",
          command: command.name,
          message: command.event.message.content,
          arguments: command.arguments.to_h,
          cooldown: command.current_cooldown&.attributes,
          response: payload[:response]
        )
      end
    end

    def self.argument_parse(name, _start, _finish, _id, payload)
      return if ESM.env.production?

      ESM.logger.debug(name) do
        parser = payload[:parser]

        ESM::JSON.pretty_generate(
          argument: payload[:argument],
          message: payload[:message],
          regex: payload[:regex],
          parser: {
            original: parser.original,
            value: parser.value
          }
        )
      end
    end

    def self.websocket_server_deliver(name, _start, _finish, _id, payload)
      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(payload[:request])
      end
    end

    def self.websocket_client_on_message(name, _start, _finish, _id, payload)
      ESM.logger.debug(name) do
        ESM::JSON.pretty_generate(payload[:event].data)
      end
    end

    def self.bot_deliver(name, _start, _finish, _id, payload)
      message = payload[:message]

      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(
          channel: "#{payload[:channel].name} (#{payload[:channel].id})",
          message: message.is_a?(ESM::Embed) ? message.to_h : message
        )
      end
    end

    def self.bot_resend_queue(name, _start, _finish, _id, payload)
      recipient_id = payload[:to].respond_to?(:id) ? payload[:to].id : payload[:to]
      exception = payload[:exception]

      ESM.logger.debug(name) do
        ESM::JSON.pretty_generate(
          message: payload[:message],
          to: recipient_id,
          exception: exception.message,
          backtrace: exception.backtrace[0..2]
        )
      end
    end

    def self.xm8_notification_invalid_type(_name, _start, _finish, _id, payload)
      server = payload[:server]
      recipients = payload[:recipients].join("\n")

      embed =
        ESM::Embed.build do |e|
          e.title = I18n.t("xm8_notifications.invalid_type.title", server: server.server_id)
          e.description = I18n.t("xm8_notifications.invalid_type.description", type: payload[:type])

          e.add_field(name: I18n.t(:message), value: "```#{payload[:message]}```")
          e.add_field(name: I18n.t("xm8_notifications.recipient_steam_uids"), value: "```#{recipients}```")

          e.color = :red
          e.footer = I18n.t("xm8_notifications.footer")
        end

      server.community.log_event(:xm8, embed)
    end

    def self.xm8_notification_invalid_attributes(_name, _start, _finish, _id, payload)
      server = payload[:server]
      recipients = payload[:recipients].join("\n")
      type = payload[:type]
      message = payload[:message]
      error, remedy = ""

      case type
      when "custom"
        error = I18n.t("xm8_notifications.invalid_attributes.custom.error")
        remedy = I18n.t("xm8_notifications.invalid_attributes.custom.remedy")
      when "marxet-item-sold"
        error = I18n.t("xm8_notifications.invalid_attributes.marxet_item_sold.error")
        remedy = I18n.t("xm8_notifications.invalid_attributes.marxet_item_sold.remedy")
      end

      embed =
        ESM::Embed.build do |e|
          e.title = I18n.t("xm8_notifications.invalid_attributes.title", server: server.server_id)
          e.description = I18n.t("xm8_notifications.invalid_attributes.description", error: error, remedy: remedy)

          log_message = I18n.t("xm8_notifications.invalid_attributes.log_message.base")
          log_message += I18n.t("xm8_notifications.invalid_attributes.log_message.title", title: message.title) if message.title.present?
          log_message += I18n.t("xm8_notifications.invalid_attributes.log_message.title", message: message.description) if message.description.present?

          e.add_field(name: I18n.t(:message), value: log_message)
          e.add_field(name: I18n.t("xm8_notifications.recipient_steam_uids"), value: "```#{recipients}```")

          e.color = :red
          e.footer = I18n.t("xm8_notifications.footer")
        end

      server.community.log_event(:xm8, embed)
    end

    def self.xm8_notification_on_send(name, _start, _finish, _id, payload)
      server = payload[:server]
      notification = payload[:embed]
      type = payload[:type]
      sent_to_users = payload[:delivered].map { |user| "#{user.discord_username}##{user.discord_discriminator} (`#{user.steam_uid}`)" }
      unregistered_steam_uids = payload[:unregistered_steam_uids]

      failed_to_send = payload[:undeliverable].map do |hash|
        user = hash[:user]
        reason= hash[:reason]

        "#{user.discord_username}##{user.discord_discriminator} (`#{user.steam_uid}`) - #{reason}"
      end

      # For debugging
      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(
          type: type,
          server: server.server_id,
          embed: notification.to_h,
          sent_to_users: sent_to_users,
          failed_to_send: failed_to_send,
          unregistered_steam_uids: unregistered_steam_uids,
          log: server.community.log_xm8_event?
        )
      end

      # Notify the community if they subscribe to this notification
      embed =
        ESM::Embed.build do |e|
          e.title = I18n.t("xm8_notifications.log.title", type: type, server: server.server_id)
          e.description = I18n.t("xm8_notifications.log.description", title: notification.title, description: notification.description)

          if sent_to_users.present?
            e.add_field(
              name: I18n.t("xm8_notifications.log.delivered_to"),
              value: sent_to_users
            )
          end

          if failed_to_send.present?
            e.add_field(
              name: I18n.t("xm8_notifications.log.undeliverable"),
              value: failed_to_send
            )
          end

          if unregistered_steam_uids.present?
            e.add_field(
              name: I18n.t("xm8_notifications.log.unregistered_steam_uids"),
              value: unregistered_steam_uids
            )
          end

          e.color = ESM::Color.random
          e.footer = I18n.t("xm8_notifications.footer")
        end

      server.community.log_event(:xm8, embed)
    end

    def self.server_on_connect(name, _start, _finish, _id, payload)
      server = payload[:server]

      ESM.logger.info(name) do
        ESM::JSON.pretty_generate(server_id: server.server_id, uptime: server.uptime)
      end

      server.community.log_event(:reconnect, I18n.t("server_connected", server: server.server_id, uptime: server.uptime))
    end

    def self.websocket_server_on_close(name, _start, _finish, _id, payload)
      server = payload[:server]

      ESM.logger.debug(name) do
        ESM::JSON.pretty_generate(bot_stopping: ESM.bot.stopping?, server_id: server.server_id, uptime: server.uptime)
      end

      message =
        if ESM.bot.stopping?
          I18n.t("server_disconnected_esm_stopping", server: server.server_id, uptime: server.uptime)
        else
          I18n.t("server_disconnected", server: server.server_id, uptime: server.uptime)
        end

      server.community.log_event(:reconnect, message)
    end
  end
end
