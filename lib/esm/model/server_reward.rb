# frozen_string_literal: true

module ESM
  class ServerReward < ApplicationRecord
    include Concerns::PublicId
    include Concerns::Cooldownable

    attribute :server_id, :integer
    attribute :reward_id, :string

    ###
    # Deprecated. Replaced with :server_reward_items
    attribute :reward_items, :hash, default: {}
    attribute :player_poptabs, :integer, limit: 8, default: 0
    attribute :locker_poptabs, :integer, limit: 8, default: 0
    attribute :respect, :integer, limit: 8, default: 0
    ###

    belongs_to :server

    has_many :server_reward_items, dependent: :destroy

    scope :default, -> { find_by(reward_id: nil) }
  end
end
