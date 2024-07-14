# frozen_string_literal: true

FactoryBot.define do
  factory :exile_construction, class: "ESM::ExileConstruction" do
    class_name do
      ESM::Arma::ClassLookup.where(mod: "exile", category: "exile_construction").keys.sample
    end

    spawned_at { Faker::Date.backwards }
    is_locked { false }
    pin_code { "00000" }
    last_updated_at { Time.current }
  end
end
