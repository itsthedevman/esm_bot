# frozen_string_literal: true

module ESM
  module Concerns
    module Cooldownable
      extend ActiveSupport::Concern

      COOLDOWN_TYPES = [
        COOLDOWN_TYPE_NEVER = "never",
        COOLDOWN_TYPE_TIMES = "times",
        COOLDOWN_TYPE_SECONDS = "seconds",
        COOLDOWN_TYPE_MINUTES = "minutes",
        COOLDOWN_TYPE_HOURS = "hours",
        COOLDOWN_TYPE_DAYS = "days",
        COOLDOWN_TYPE_WEEKS = "weeks",
        COOLDOWN_TYPE_MONTHS = "months",
        COOLDOWN_TYPE_YEARS = "years"
      ].freeze

      included do
        attribute :cooldown_quantity, :integer, default: 2
        enum :cooldown_type, COOLDOWN_TYPES.to_h { |t| [t, t] }, default: COOLDOWN_TYPE_SECONDS
      end

      def cooldown_duration
        return if cooldown_type == COOLDOWN_TYPE_NEVER
        return cooldown_quantity.times if cooldown_type == COOLDOWN_TYPE_TIMES

        cooldown_quantity.public_send(cooldown_type)
      end
    end
  end
end
