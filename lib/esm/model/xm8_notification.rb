# frozen_string_literal: true

module ESM
  class Xm8Notification < ImmutableStruct.define(:id, :recipient_uid, :content, :created_at)
    class InvalidContent < Exception::Error
    end

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

    def self.from(hash)
      type = hash[:type]
      klass = TYPES[type]
      raise NameError, "\"#{type}\" is not a valid XM8 notification type" unless klass

      hash[:content] = hash[:content].to_istruct

      notification = klass.new(**hash)
      notification.validate!
      notification
    end

    def type
      @type ||= self.class.name.dasherize
    end

    def validate!
      raise InvalidContent unless notification.valid?
    end

    def valid?
      # Most notifications are about a territory
      content.territory_id.present? && content.territory_name.present?
    end
  end
end
