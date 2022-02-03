# frozen_string_literal: true

module ESM
  class UserNotificationRoute < ESM::ApplicationRecord
    attribute :user_id, :integer
    attribute :community_id, :integer
    attribute :server_id, :integer
    attribute :notification_type, :string
    attribute :enabled, :boolean, default: true
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :user
    belongs_to :community
    belongs_to :server

    validates :user_id, :community_id, :server_id, :notification_type, presence: true
  end
end
