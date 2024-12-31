# frozen_string_literal: true

module ESM
  module Concerns
    module Cooldownable
      extend ActiveSupport::Concern

      COOLDOWN_TYPES = [
        COOLDOWN_TIMES = "times",
        COOLDOWN_SECONDS = "seconds",
        COOLDOWN_MINUTES = "minutes",
        COOLDOWN_HOURS = "hours",
        COOLDOWN_DAYS = "days",
        COOLDOWN_WEEKS = "weeks",
        COOLDOWN_MONTHS = "months",
        COOLDOWN_YEARS = "years"
      ].freeze

      included do
        attribute :cooldown_quantity, :integer, default: 2
        enum :cooldown_type, COOLDOWN_TYPES.to_h { |t| [t, t] }, default: COOLDOWN_SECONDS
      end

      def cooldown_duration
        return cooldown_quantity.times if cooldown_type == COOLDOWN_TIMES

        cooldown_quantity.public_send(cooldown_type)
      end
    end
  end
end
