# frozen_string_literal: true

FactoryBot.define do
  factory :server_reward, class: "ESM::ServerReward" do
    # attribute :server_id, :integer
    # attribute :reward_items, :json, default: nil
    # attribute :player_poptabs, :integer, default: 0
    # attribute :locker_poptabs, :integer, default: 0
    # attribute :respect, :integer, default: 0

    reward_vehicles do
      reward_vehicles = []

      vehicles = ESM::Arma::ClassLookup.where(category: ESM::Arma::ClassLookup::CATEGORY_VEHICLES)
      Faker::Number.between(from: 2, to: 20).times do
        reward_vehicles << { class_name: vehicles.sample.class_name, spawn_location: Faker::Boolean.boolean ? "nearby" : "virtual_garage" }
      end

      reward_vehicles
    end

    reward_items do
      reward_items = {}

      items = ESM::Arma::ClassLookup.where(category: ESM::Arma::ClassLookup::CATEGORY_EXILE)
      Faker::Number.between(from: 2, to: 20).times do
        reward_items[items.sample.class_name] = Faker::Number.between(from: 1, to: 5)
      end

      reward_items
    end

    player_poptabs { Faker::Number.between(from: 1000, to: 20_000) }
    locker_poptabs { Faker::Number.between(from: 1000, to: 20_000) }
    respect { Faker::Number.between(from: 1000, to: 20_000) }
  end
end
