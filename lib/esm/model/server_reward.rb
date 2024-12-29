# frozen_string_literal: true

module ESM
  class ServerReward < ApplicationRecord
    attribute :server_id, :integer
    attribute :cooldown_quantity, :integer
    attribute :cooldown_type, :string

    ###
    # Deprecated. Replaced with :server_reward_items
    # Never used
    attribute :reward_id, :string
    attribute :reward_vehicles, :hash, default: []

    # Valid attributes:
    #   class_name <String>
    #   quantity <Integer>
    attribute :reward_items, :hash, default: {}
    attribute :player_poptabs, :integer, limit: 8, default: 0
    attribute :locker_poptabs, :integer, limit: 8, default: 0
    attribute :respect, :integer, limit: 8, default: 0
    ###

    has_many :server_reward_items, dependent: :destroy

    belongs_to :server

    scope :default, -> { where(reward_id: nil).first }
  end
end
