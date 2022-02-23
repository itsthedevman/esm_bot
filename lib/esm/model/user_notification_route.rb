# frozen_string_literal: true

module ESM
  class UserNotificationRoute < ESM::ApplicationRecord
    attribute :uuid, :string
    attribute :user_id, :integer
    attribute :community_id, :integer
    attribute :server_id, :integer # nil means "any server"
    attribute :channel_id, :string
    attribute :notification_type, :string
    attribute :user_accepted, :boolean, default: false
    attribute :community_accepted, :boolean, default: false
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :user
    belongs_to :community
    belongs_to :server

    validates :uuid, :user_id, :community_id, :channel_id, presence: true
    validates :notification_type, presence: true, uniqueness: { scope: %i[user_id community_id server_id channel_id] }

    TYPES = %w[
      custom
      base-raid
      flag-stolen
      flag-restored
      flag-steal-started
      protection-money-due
      protection-money-paid
      grind-started
      hack-started
      charge-plant-started
      marxet-item-sold
    ].freeze
  end
end
