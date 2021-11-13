# frozen_string_literal: true

module ESM
  class Community < ApplicationRecord
    before_create :generate_community_id
    before_create :set_command_prefix
    after_create :create_command_configurations
    after_create :create_notifications

    attribute :community_id, :string
    attribute :community_name, :text
    attribute :guild_id, :string
    attribute :logging_channel_id, :string
    attribute :log_reconnect_event, :boolean, default: false
    attribute :log_xm8_event, :boolean, default: true
    attribute :log_discord_log_event, :boolean, default: true
    attribute :log_error_event, :boolean, default: true
    attribute :player_mode_enabled, :boolean, default: true
    attribute :territory_admin_ids, :json, default: []
    attribute :command_prefix, :string, default: nil
    attribute :welcome_message_enabled, :boolean, default: true
    attribute :welcome_message, :string, default: ""
    attribute :created_at, :datetime
    attribute :updated_at, :datetime
    attribute :deleted_at, :datetime

    has_many :command_configurations
    has_many :cooldowns
    has_many :notifications
    has_many :servers

    alias_attribute :name, :community_name

    attr_accessor :guild_type if ESM.env.test?

    module ESM
      ID = "414643176947843073"
      SPAM_CHANNEL = ENV["SPAM_CHANNEL"]
    end

    module Secondary
      ID = ENV["SECONDARY_COMMUNITY_ID"]
      SPAM_CHANNEL = ENV["SECONDARY_SPAM_CHANNEL"]
    end

    def self.community_ids
      @community_ids ||= self.all.pluck(:community_id)
    end

    def self.correct(id)
      checker = DidYouMean::SpellChecker.new(dictionary: community_ids)
      checker.correct(id)
    end

    def self.find_by_community_id(id)
      default_scoped.includes(:servers).order(:community_id).where(community_id: id).first
    end

    def self.find_by_guild_id(id)
      default_scoped.includes(:servers).order(:guild_id).where(guild_id: id).first
    end

    def self.find_by_server_id(id)
      return if id.blank?

      # esm_malden -> esm
      community_id = id.match(/([^\s]+)_[^\s]+/i)
      return if community_id.nil?

      find_by_community_id(community_id[1])
    end

    def logging_channel
      ::ESM.bot.channel(self.logging_channel_id)
    end

    def discord_server
      ::ESM.bot.server(self.guild_id)
    end

    def log_event(event, message)
      return if self.logging_channel_id.blank?

      # Only allow logging events to logging channel if permission has been given
      case event
      when :xm8
        return if !self.log_xm8_event
      when :discord_log
        return if !self.log_discord_log_event
      when :reconnect
        return if !self.log_reconnect_event
      when :error
        return if !self.log_error_event
      else
        raise ::ESM::Exception::Error, "Attempted to log :#{event} to #{self.guild_id} without explicit permission.\nMessage:\n#{message}"
      end

      # Check this first to avoid an infinite loop if the bot cannot send a message to this channel
      # since this method is called from the #deliver method for this exact reason.
      channel = self.logging_channel
      member = ::ESM.bot.profile.on(channel.server)
      return ::ESM.bot.deliver(message, to: channel) if member.permission?(:send_messages, channel)

      # The bot did not have permission. Send the owner a message letting them know
      embed = ::ESM::Embed.build(:error, description: I18n.t("exceptions.logging_channel_access_denied", community_name: self.community_name, channel_name: channel.name))

      ::ESM.bot.deliver(embed, to: channel.server.owner)
    end

    private

    def set_command_prefix
      self.command_prefix = ::ESM.config.prefix
    end

    def generate_community_id
      return if self.community_id.present?

      count = 0
      new_id = nil

      loop do
        # Attempt to generate an id. Top rated comment from this answer: https://stackoverflow.com/a/88341
        new_id = ('a'..'z').to_a.sample(4).join
        count += 1

        # Our only saviors
        break if count > 10_000
        break if self.class.find_by_community_id(new_id).nil?
      end

      # Yup. Add to the community_ids so our spell checker works
      self.class.community_ids << new_id
      self.community_id = new_id
    end

    def create_command_configurations
      configurations = ::ESM::Command.configurations.map { |c| c.merge(community_id: self.id) }
      ::ESM::CommandConfiguration.import(configurations)
    end

    def create_notifications
      ::ESM::Notification::DEFAULTS.each do |category, notifications|
        notifications =
          notifications.map do |notification|
            {
              community_id: self.id,
              notification_type: notification["type"],
              notification_title: notification["title"],
              notification_description: notification["description"],
              notification_color: notification["color"],
              notification_category: category
            }
          end

        ::ESM::Notification.import(notifications)
      end
    end
  end
end
