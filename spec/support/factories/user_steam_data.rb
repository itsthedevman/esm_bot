# frozen_string_literal: true

FactoryBot.define do
  factory :user_steam_data, class: "ESM::UserSteamData" do
    username { Faker::String.random }
  end
end
