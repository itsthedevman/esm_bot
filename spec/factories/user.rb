# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "ESM::User" do
    transient do
      user do
        user_id = ESM::Test.data[:primary][:users].sample
        user = ESM.bot.user(user_id)

        {
          id: user_id,
          name: user.username,
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
            name: user.username,
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

      trait :with_role do
        transient do
          user do
            user_data = ESM::Test.data[:primary][:role_users].sample
            user = ESM.bot.user(user_data[:id])

            user_data.merge(
              name: user.username,
              discriminator: user.discriminator,
              steam_uid: ESM::Test.data[:steam_uids].sample
            )
          end
        end

        discord_id { user[:id] }
        discord_username { user[:name] }
        discord_discriminator { user[:discriminator] }
        steam_uid { user[:steam_uid] }
        role_id { user[:role_id] }
      end
    end

    factory :secondary_user do
      transient do
        user do
          user_id = ESM::Test.data[:secondary][:users].sample
          user = ESM.bot.user(user_id)

          {
            id: user_id,
            name: user.username,
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

      trait :with_role do
        transient do
          user do
            user_data = ESM::Test.data[:secondary][:role_users].sample
            user = ESM.bot.user(user_data[:id])

            user_data.merge(
              name: user.username,
              discriminator: user.discriminator,
              steam_uid: ESM::Test.data[:steam_uids].sample
            )
          end
        end

        discord_id { user[:id] }
        discord_username { user[:name] }
        discord_discriminator { user[:discriminator] }
        steam_uid { user[:steam_uid] }
        role_id { user[:role_id] }
      end
    end
  end
end
