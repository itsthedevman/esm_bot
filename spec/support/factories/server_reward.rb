# frozen_string_literal: true

FactoryBot.define do
  factory :server_reward, class: "ESM::ServerReward" do
    reward_items do
      reward_items = {}

      items = ESM::Arma::ClassLookup.where(mod: "exile", category: "exile_consumables")
      Faker::Number.between(from: 2, to: 10).times do
        reward_items[items.keys.sample] = Faker::Number.between(from: 1, to: 5)
      end

      reward_items
    end

    player_poptabs { Faker::Number.between(from: 1000, to: 20_000) }
    locker_poptabs { Faker::Number.between(from: 1000, to: 20_000) }
    respect { Faker::Number.between(from: 1000, to: 20_000) }
  end
end
