# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "ESM::User" do
    transient do
      not_user {}
      users { YAML.load_file("#{File.expand_path("./spec/support/config")}/test_users.yml").map(&:deep_symbolize_keys) }
      user { users.sample }
    end

    # attribute :discord_id, :string
    # attribute :discord_username, :string
    # attribute :discord_discriminator, :string
    # attribute :discord_avatar, :text, default: nil
    # attribute :discord_access_token, :string, default: nil
    # attribute :discord_refresh_token, :string, default: nil
    # attribute :steam_uid, :string, default: nil
    # attribute :created_at, :datetime
    # attribute :updated_at, :datetime
    discord_id { user[:id] }
    discord_username { user[:name] }
    discord_discriminator { user[:discriminator] }
    steam_uid { user[:steam_uid] }

    # Tracks the type of guild the user has joined
    # :primary for Exile Server Manager, :secondary for my test server
    guild_type { :primary }

    before(:create) do |user, evaluator|
      next if evaluator.not_user.nil?

      # Create another user that isn't the discord ID passed in
      new_user = evaluator.users.reject { |u| u[:id] == evaluator.not_user.discord_id }.sample
      user.discord_id = new_user[:id]
      user.discord_username = new_user[:name]
      user.discord_discriminator = new_user[:discriminator]
      user.steam_uid = new_user[:steam_uid]
    end

    trait :unregistered do
      steam_uid { nil }
    end

    factory :esm_dev do
      transient do
        user { ESM::Test.data[:dev] }
        discord_user { ESM.bot.user(user[:id]) }
      end

      discord_id { user[:id] }
      discord_username { discord_user.username }
      discord_discriminator { discord_user.discriminator }
      steam_uid { user[:steam_uid] }
      guild_type { :primary }
    end

    factory :primary_user do
      transient do
        user do
          user_id = ESM::Test.data[:primary][:users].sample
          user = ESM.bot.user(user_id)

          {
            id: user_id,
            name: user.name,
            discriminator: user.discriminator,
            steam_uid: ESM::Test.data[:steam_uids].sample
          }
        end
      end

      discord_id { user[:id] }
      discord_username { user[:name] }
      discord_discriminator { user[:discriminator] }
      steam_uid { user[:steam_uid] }
      guild_type { :primary }
    end

    factory :secondary_user do
      transient do
        user do
          user_id = ESM::Test.data[:secondary][:users].sample
          user = ESM.bot.user(user_id)

          {
            id: user_id,
            name: user.name,
            discriminator: user.discriminator,
            steam_uid: ESM::Test.data[:steam_uids].sample
          }
        end
      end

      discord_id { user[:id] }
      discord_username { user[:name] }
      discord_discriminator { user[:discriminator] }
      steam_uid { user[:steam_uid] }
      guild_type { :secondary }
    end

    factory :user_with_role do
      transient do
        user { ESM::Test.data[:primary][:role_user] }
        discord_user { ESM.bot.user(user[:id]) }
      end

      discord_id { user[:id] }
      discord_username { discord_user.username }
      discord_discriminator { discord_user.discriminator }
      steam_uid { user[:steam_uid] }
      guild_type { :primary }
    end
  end
end
