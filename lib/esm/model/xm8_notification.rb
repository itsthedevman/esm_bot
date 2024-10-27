# frozen_string_literal: true

module ESM
  class Xm8Notification < ImmutableStruct.define(
    :id, :uuids, :recipient_uids, :server,
    :content, :created_at
  )
    TYPES = {
      "base-raid": BaseRaid,
      "charge-plant-started": ChargePlantStarted,
      custom: Custom,
      "flag-restored": FlagRestored,
      "flag-steal-started": FlagStealStarted,
      "flag-stolen": FlagStolen,
      "grind-started": GrindStarted,
      "hack-started": HackStarted,
      "marxet-item-sold": MarxetItemSold,
      "protection-money-due": ProtectionMoneyDue,
      "protection-money-paid": ProtectionMoneyPaid
    }.with_indifferent_access.freeze

    STATUS_NOT_REGISTERED = "recipient_not_registered"

    class InvalidType < Exception::Error
    end

    class InvalidContent < Exception::Error
    end

    def self.from(hash)
      type = hash[:type]
      klass = TYPES[type]
      raise InvalidType, "\"#{type}\" is not a valid XM8 notification type" if klass.nil?

      hash[:content] = hash[:content].to_istruct

      notification = klass.new(**hash.without(:type))
      notification.validate!
      notification
    end

    def initialize(**opts)
      # ID is internal for tracking purposes
      opts[:id] = SecureRandom.uuid

      new(**opts)
    end

    def type
      @type ||= self.class.name.dasherize
    end

    def send_to_recipients
      status = {success: [], failure: []}
      user_ids = users.map(&:id)

      send_to_dm(status, user_ids)
      send_to_custom_routes(status, user_ids)

      status
    end

    def reject_unregistered_uids!(uid_lookup)
      unregistered = []

      recipient_uids.each_with_index.reverse_each do |uid, index|
        next if uid_lookup.include?(uid)

        unregistered << uid

        recipient_uids.delete_at(index)
        uuids.delete_at(index)
      end

      unregistered
    end

    def users
      @users ||= User.where(steam_uid: recipient_uids).select_for_xm8_notifications
    end

    def to_embed(context)
      @embed ||= lambda do
        embed = ESM::Notification.build_random(**context.merge(type:, category: "xm8"))
        embed.footer = "[#{context.server_id}] #{context.server_name}"
        embed
      end.call
    end

    def each_recipient(&)
      raise "UUIDs and users do not match in size" if uuids.size != users.size

      uuids.zip(users).each(&)
    end

    private

    def validate!
      raise InvalidContent unless valid?
    end

    def valid?
      # Most notifications are about a territory
      content.territory_id.present? && content.territory_name.present?
    end

    def send_to_dm(status, user_ids)
      preferences_by_user_id = ESM::UserNotificationPreference.where(user_id: user_ids)
        .pluck(:user_id, type.underscore)
        .to_h

      # Default the preference to allow.
      # This is needed if the user hasn't ran the preference command before
      preferences_by_user_id.default = true

      each_recipient do |uuid, user|
        dm_allowed = preferences_by_user_id[user.id]
        next unless dm_allowed

        message = ESM.bot.deliver(to_embed, to: user.discord_user, block: true)

        status[message ? :success : :failure] << uuid
      end
    end

    def send_to_custom_routes(status, user_ids)
      user_lookup = users.to_h { |u| [u.id, u] }

      # Custom routes are a little different.
      #   Using a mention in an embed does not cause a "notification" on discord.
      #     This does not work since these are often urgent.
      #   To get around this, routes need to be grouped by channel.
      #   From here, an initial message can be sent tagging each user with this channel (and type)
      users_by_channel_id = ESM::UserNotificationRoute.select(:user_id, :channel_id)
        .enabled
        .accepted
        .where(notification_type: type, user_id: user_ids)
        .where("source_server_id IS NULL OR source_server_id = ?", server.id)
        .group_by(&:channel_id)

      # TODO: handle working this into #each_recipient
      users_by_channel_id.each_with_object({}) do |(channel_id, routes), status|
        users = routes.map { |route| user_lookup[route.user_id] }

        message = ESM.bot.deliver(
          embed,
          to: channel_id,
          embed_message: "#{type.titleize} - #{users.map(&:mention).join(" ")}",
          block: true
        )
      end
    end
  end
end
