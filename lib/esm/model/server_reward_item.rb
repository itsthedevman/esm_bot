# frozen_string_literal: true

module ESM
  class ServerRewardItem < ApplicationRecord
    TYPES = [
      POPTABS = "poptabs",
      RESPECT = "respect",
      CLASSNAME = "classname"
    ].freeze

    before_create :generate_public_id

    attribute :public_id, :uuid
    attribute :server_reward_id, :integer
    attribute :reward_type, :string
    attribute :classname, :string
    attribute :amount, :integer
    attribute :expiry_value, :integer, default: nil
    attribute :expiry_unit, :string, default: "never"
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :server_reward

    private

    def generate_public_id
      return if public_id.present?

      self.public_id = SecureRandom.uuid
    end
  end
end
