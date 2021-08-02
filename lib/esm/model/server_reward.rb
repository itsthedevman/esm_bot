# frozen_string_literal: true

module ESM
  class ServerReward < ApplicationRecord
    attribute :server_id, :integer
    attribute :reward_id, :string

    # Valid attributes:
    #   class_name <String>
    #   quantity <Integer>
    attribute :reward_items, :json, default: {}

    # Valid attributes:
    #   class_name <String>
    #   spawn_location <String> Valid options: "nearby", "virtual_garage"
    attribute :reward_vehicles, :json, default: []

    attribute :player_poptabs, :integer, limit: 8, default: 0
    attribute :locker_poptabs, :integer, limit: 8, default: 0
    attribute :respect, :integer, limit: 8, default: 0
    attribute :cooldown_quantity, :integer
    attribute :cooldown_type, :string

    belongs_to :server

    scope :default, -> { where(reward_id: nil).first }
  end
end
