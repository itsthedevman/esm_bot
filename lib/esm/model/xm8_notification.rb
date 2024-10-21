# frozen_string_literal: true

module ESM
  class Xm8Notification < ImmutableStruct.define(:uuids, :recipient_uids, :content, :created_at)
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

    def type
      @type ||= self.class.name.dasherize
    end

    def validate!
      raise InvalidContent unless valid?
    end

    def valid?
      # Most notifications are about a territory
      content.territory_id.present? && content.territory_name.present?
    end

    def to_embed(context)
      embed = ESM::Notification.build_random(**context.merge(type:, category: "xm8"))
      embed.footer = "[#{context.server_id}] #{context.server_name}"
      embed
    end
  end
end
