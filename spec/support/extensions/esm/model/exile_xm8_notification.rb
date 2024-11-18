# frozen_string_literal: true

module ESM
  class ExileXm8Notification < ArmaRecord
    self.inheritance_column = nil
    self.table_name = "xm8_notification"

    attribute :uuid, :string, default: -> { SecureRandom.uuid }
    attribute :recipient_uid, :string
    attribute :territory_id, :integer, default: nil
    attribute :type, :string
    attribute :content, :json
    attribute :state, :string, default: "new"
    attribute :state_details, :string
    attribute :attempt_count, :integer, default: 0
    attribute :created_at, :datetime, default: -> { Time.current }
    attribute :last_attempt_at, :datetime
    attribute :acknowledged_at, :datetime

    belongs_to :account,
      class_name: "ESM::ExileAccount",
      foreign_key: "recipient_uid"

    belongs_to :territory,
      class_name: "ESM::ExileTerritory",
      foreign_key: "territory_id",
      optional: true
  end
end
