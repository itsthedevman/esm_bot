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

    def vehicles
      @vehicles ||= reward_vehicles.map do |vehicle_data|
        class_name = vehicle_data[:class_name]
        limited_to = vehicle_data[:limited_to]
        display_name = ESM::Arma::ClassLookup.find(class_name).try(:display_name) || class_name

        {class_name:, display_name:, limited_to:}
      end
    end

    def items
      @items ||= reward_items.map do |class_name, quantity|
        display_name = ESM::Arma::ClassLookup.find(class_name).try(:display_name) || class_name

        {class_name:, display_name:, quantity:}
      end
    end
  end
end
