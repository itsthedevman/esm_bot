# frozen_string_literal: true

module ESM
  class User < ApplicationRecord
    after_create :create_user_steam_data
    after_create :create_id_defaults

    attribute :discord_id, :string
    attribute :discord_username, :string
    attribute :discord_discriminator, :string
    attribute :discord_avatar, :text, default: nil
    attribute :discord_access_token, :string, default: nil
    attribute :discord_refresh_token, :string, default: nil
    attribute :steam_uid, :string, default: nil
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    has_many :cooldowns, dependent: :nullify
    has_many :id_aliases, class_name: "UserAlias", dependent: :destroy
    has_one :id_defaults, class_name: "UserDefault", dependent: :destroy
    has_many :logs, class_name: "Log", foreign_key: "requestors_user_id", dependent: :destroy
    has_many :my_requests, foreign_key: :requestor_user_id, class_name: "Request", dependent: :destroy
    has_many :pending_requests, foreign_key: :requestee_user_id, class_name: "Request", dependent: :destroy
    has_many :user_gamble_stats, dependent: :destroy
    has_many :user_notification_preferences, dependent: :destroy
    has_many :user_notification_routes, dependent: :destroy
    has_one :user_steam_data, dependent: :destroy

    validates :discord_id, uniqueness: true, presence: true
    validates :steam_uid, uniqueness: true

    #########################
    # Public Methods
    #########################

    # Parses and finds a user based off of SteamUID, Discord ID, or Discord Mention
    def self.parse(input)
      return nil if input.nil?

      # In case of frozen strings
      input = input.dup if input.frozen?

      # Discordrb stores the Discord ID as an Integer.
      input = input.to_s if !input.is_a?(String)

      if ESM::Regex::DISCORD_TAG_ONLY.match(input)
        # Remove the extra stuff from a mention
        find_by_discord_id(input.gsub(/[<@!&>]/, ""))
      elsif ESM::Regex::STEAM_UID_ONLY.match(input)
        find_by_steam_uid(input)
      else
        find_by_discord_id(input)
      end
    end

    def self.find_by_steam_uid(uid)
      order(:steam_uid).where(steam_uid: uid).first
    end

    def self.find_by_discord_id(id)
      id = id.to_s if !id.is_a?(String)
      order(:discord_id).where(discord_id: id).first
    end

    #########################
    # Instance Methods
    #########################

    def steam_data
      @steam_data ||= lambda do
        # If the data is stale, it will automatically refresh
        user_steam_data.refresh
        user_steam_data
      end.call
    end

    def registered?
      steam_uid.present?
    end

    def developer?
      ESM.config.dev_user_whitelist.include?(discord_id)
    end

    def mention
      "<@#{discord_id}>"
    end

    def distinct
      "#{discord_username}##{discord_discriminator}"
    end

    def discord_user
      @discord_user ||= lambda do
        discord_user = ESM.bot.user(discord_id)
        return if discord_user.nil?

        # Keep the discord user data up-to-date
        incoming_attributes = [discord_user.username, discord_user.discriminator, discord_user.avatar_url]
        current_attributes = [discord_username, discord_discriminator, discord_avatar]

        if current_attributes != incoming_attributes
          update(
            discord_username: discord_user.username,
            discord_discriminator: discord_user.discriminator,
            discord_avatar: discord_user.avatar_url
          )
        end

        # Save some data for later consumption
        discord_user.esm_user = self

        discord_user
      end.call
    end

    def discord_servers
      @discord_servers ||= ESM.bot.servers.values.select do |server|
        server.users.any? { |user| user.id.to_s == discord_id }
      end
    end

    def can_modify?(guild_id)
      return true if developer? && !Rails.env.development?

      community = Community.find_by_guild_id(guild_id)
      return false if community.nil?

      server = community.discord_server
      return false if server.nil?

      # Check if they're the owner or admin
      community.modifiable_by?(discord_user.on(server))
    end

    def channel_permission?(permission, channel)
      discord_user&.on(channel.server)&.permission?(permission, channel) || false
    end
  end
end
