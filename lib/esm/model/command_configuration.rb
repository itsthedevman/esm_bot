# frozen_string_literal: true

module ESM
  class CommandConfiguration < ApplicationRecord
    include Concerns::Cooldownable

    attribute :community_id, :integer
    attribute :command_name, :string
    attribute :enabled, :boolean, default: true
    attribute :notify_when_disabled, :boolean, default: true
    attribute :allowed_in_text_channels, :boolean, default: true
    attribute :allowlist_enabled, :boolean, default: false
    attribute :allowlisted_role_ids, :json, default: []
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :community
  end
end
