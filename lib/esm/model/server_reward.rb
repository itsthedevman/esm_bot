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
    #   spawn_location <String> Valid options: "nearby", "virtual_garage", "player_decides"
    attribute :reward_vehicles, :json, default: []

    attribute :player_poptabs, :integer, limit: 8, default: 0
    attribute :locker_poptabs, :integer, limit: 8, default: 0
    attribute :respect, :integer, limit: 8, default: 0
    attribute :cooldown_quantity, :integer
    attribute :cooldown_type, :string

    belongs_to :server

    scope :default, -> { where(reward_id: nil).first }

    def itemize
      output = ["**Player**"]
      output << "\t+#{self.player_poptabs.to_poptab} (Wallet)" if self.player_poptabs.positive?
      output << "\t+#{self.locker_poptabs.to_poptab} (Locker)" if self.locker_poptabs.positive?
      output << "\t+#{self.respect} Respect" if self.respect.positive?
      output += itemize_items if self.reward_items.present?
      output += itemize_vehicles if self.reward_vehicles.present?

      output.join("\n")
    end

    def vehicles
      @vehicles ||= self.reward_vehicles.map do |vehicle_data|
        class_name = vehicle_data["class_name"]
        spawn_location = vehicle_data["spawn_location"]
        display_name = ESM::Arma::ClassLookup.find(class_name).try(:display_name) || class_name

        { class_name: class_name, display_name: display_name, spawn_location: spawn_location }
      end
    end

    private

    #
    # Load the items sorted by their display/class name.
    # This will also attempt to convert the class name into a display name.
    #
    # @return [Array<String>] The items in this reward
    #
    def itemize_items
      output = ["**Items**"]

      items = self.reward_items.transform_keys do |class_name|
        ESM::Arma::ClassLookup.find(class_name).try(:display_name) || class_name
      end

      items.sort_by { |name, _| name }.each do |display_name, quantity|
        output << "\t#{quantity}x #{display_name}"
      end

      output
    end

    #
    # Loads the vehicles for this reward, sorted by their class names.
    # This will also attempt to convert the class name into a display name
    #
    # @return [Array<String>] The vehicles in this reward
    #
    def itemize_vehicles
      output = ["**Vehicles _(spawn location)_**"]

      vehicles.sort_by { |v| v[:name] }.each do |vehicle_data|
        output << "\t#{vehicle_data[:name]} _(#{vehicle_data[:location]})_"
      end

      output
    end
  end
end
