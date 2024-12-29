# frozen_string_literal: true

module ESM
  class ServerRewardItem < ApplicationRecord
    include Concerns::PublicId

    TYPES = [
      POPTABS = "poptabs",
      RESPECT = "respect",
      CLASSNAME = "classname"
    ].freeze

    attribute :public_id, :uuid
    attribute :server_reward_id, :integer
    attribute :reward_type, :string
    attribute :classname, :string
    attribute :amount, :integer
    attribute :expiry_value, :integer, default: 0
    attribute :expiry_unit, :string, default: "never"
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :server_reward
  end
end
