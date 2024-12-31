# frozen_string_literal: true

module ESM
  class ServerRewardItem < ApplicationRecord
    include Concerns::PublicId

    TYPES = [
      POPTABS = "poptabs",
      RESPECT = "respect",
      CLASSNAME = "classname"
    ].freeze

    EXPIRY_TYPES = [
      NEVER = "never",
      TIMES = "times",
      SECONDS = "seconds",
      MINUTES = "minutes",
      HOURS = "hours",
      DAYS = "days",
      WEEKS = "weeks",
      MONTHS = "months",
      YEARS = "years"
    ].freeze

    attribute :public_id, :uuid
    attribute :server_reward_id, :integer
    enum :reward_type, TYPES.to_h { |t| [t, t] }
    attribute :classname, :string
    attribute :quantity, :integer

    attribute :expiry_value, :integer, default: 0
    enum :expiry_unit, EXPIRY_TYPES.to_h { |t| [t, t] }, default: NEVER

    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :server_reward

    def display_name
      ESM::Arma::ClassLookup.find(classname)&.display_name || classname
    end

    def expires_at
      return if expiry_unit == NEVER
      return expiry_value.times if expiry_unit == TIMES

      Time.current + expiry_value.public_send(expiry_unit)
    end
  end
end
