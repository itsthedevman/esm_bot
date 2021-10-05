# frozen_string_literal: true

require "esm"

ESM::Database.connect!
ESM::Command.load_commands

ESM::BotAttribute.create!(
  maintenance_mode_enabled: false,
  maintenance_message: "",
  status_type: "PLAYING",
  status_message: "rewards v2 dev"
)

user = ESM::User.create!(
  discord_id: "137709767954137088",
  discord_username: "Bryan",
  discord_discriminator: "9876",
  steam_uid: "76561198037177305"
)

community = ESM::Community.create!(
  community_id: "esm",
  community_name: "Exile Server Manager",
  guild_id: ESM::Community::ESM::ID,
  logging_channel_id: "446353502038654987",
  command_prefix: "pls ",
  player_mode_enabled: false
)

ESM::Community.create!(
  community_id: "test",
  community_name: "Bryan's Test Server",
  guild_id: ESM::Community::Secondary::ID,
  command_prefix: "~"
)

ESM::Community.create!(
  community_id: "zdt",
  community_name: "ZDT",
  guild_id: "421111581267591168"
)

server = ESM::Server.create!(
  community_id: community.id,
  server_id: "esm_malden",
  server_name: "Exile Server Manager",
  server_key: "ee3686ece9e84c9ba4ce86182dff487f87c0a2a5004145bfb3e256a3d96ab6f01d7c6ca0a48240c29f365e10eca3ee55edb333159c604dff815ec74cba72658a553461649c554e47ab20693a1079d1c6bf8718220d704366ab315b6b3a4cbbac6b82ac2c2f3c469f9a25e134baa0df9d",
  server_ip: "127.0.0.1",
  server_port: "2602"
)

ESM::Server.create!(
  community_id: community.id,
  server_id: "esm_test",
  server_name: "Exile Server Manager (Test)",
  server_key: "ee3686ece9e84c9ba4ce86182dff487f87c0a2a5004145bfb3e256a3d96ab6f01d7c6ca0a48240c29f365e10eca3ee55edb332658a553461649c554e47ab20693a1079d1c6bf8718220d704366ab315b6b3a4cbbac6b82ac2c2f3c469f9a25e134baa0df9d",
  server_ip: "127.0.0.1",
  server_port: "2302"
)

ESM::ServerMod.create!(
  server_id: server.id,
  mod_name: "Exile",
  mod_link: "https://www.exilemod.com",
  mod_version: "1.0.5",
  mod_required: true
)

ESM::ServerMod.create!(
  server_id: server.id,
  mod_name: "ADT",
  mod_link: "",
  mod_version: "1",
  mod_required: false
)

# This is the default reward
server.server_rewards.where(reward_id: nil).first.update!(
  server_id: server.id,
  reward_id: nil,
  reward_items: {
    Exile_Item_WoodDoorKit: 1,
    Exile_Item_WoodWallKit: 3,
    Exile_Item_WoodFloorKit: 2
  },
  reward_vehicles: [],
  player_poptabs: 12_345,
  locker_poptabs: 98_765,
  respect: 1
)

server.server_rewards.create!(
  server_id: server.id,
  reward_id: "vehicles",
  reward_items: {},
  reward_vehicles: [
    {
      class_name: "Exile_Car_Hatchback_Beige",
      spawn_location: "nearby"
    },
    {
      class_name: "Exile_Chopper_Huron_Black",
      spawn_location: "virtual_garage"
    },
    {
      class_name: "Exile_Car_Hunter",
      spawn_location: "player_decides"
    }
  ],
  player_poptabs: 0,
  locker_poptabs: 0,
  respect: 0
)

ESM::UserNotificationPreference.create!(user_id: user.id, server_id: server.id)
