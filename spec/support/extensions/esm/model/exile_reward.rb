# frozen_string_literal: true

module ESM
  class ExileReward < ArmaRecord
    self.table_name = "reward"

    attribute :public_id, :string # 8 char uuid
    attribute :account_uid, :string
    attribute :reward_type, :string
    attribute :classname, :string, default: nil
    attribute :amount, :integer, default: nil
    attribute :source, :string, default: nil
    attribute :expires_at, :datetime, default: nil
    attribute :redeemed_at, :datetime, default: nil
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :account, class_name: "ESM::ExileAccount", inverse_of: :player
  end
end
