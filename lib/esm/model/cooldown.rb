# frozen_string_literal: true

module ESM
  class Cooldown < ApplicationRecord
    include Concerns::PublicId
    include Concerns::Cooldownable

    TYPES = [
      COMMAND = "command",
      REWARD = "reward"
    ].freeze

    self.inheritance_column = nil

    attribute :community_id, :integer
    attribute :server_id, :integer
    attribute :user_id, :integer
    attribute :steam_uid, :string

    enum :type, TYPES.to_h { |t| [t, t] }
    attribute :key, :string

    attribute :cooldown_amount, :integer, default: 0
    attribute :expires_at, :datetime, default: -> { 1.second.ago }
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :community
    belongs_to :user, optional: true # This could be a user_id or steam_uid
    belongs_to :server, optional: true # Not all commands are server based

    after_find :adjust_for_community_changes

    def user
      return ESM::User.where(id: user_id).first if user_id.present?
      return ESM::User.find_by_steam_uid(steam_uid) if steam_uid.present?

      nil
    end

    def active?
      if cooldown_type == COOLDOWN_TIMES
        cooldown_amount >= cooldown_quantity
      else
        expires_at >= ::Time.current
      end
    end

    def to_s
      if cooldown_type == COOLDOWN_TIMES
        remaining = remaining_uses
        "#{remaining} time".pluralize(remaining)
      else
        ESM::Time.distance_of_time_in_words(expires_at)
      end
    end

    def reset!
      update!(expires_at: 5.seconds.ago, cooldown_amount: 0)
    end

    def update_expiry!(executed_at, cooldown_time)
      case cooldown_time
      # 1.times, 5.times...
      when Enumerator, Integer
        update!(
          cooldown_quantity: cooldown_time.is_a?(Integer) ? cooldown_time : cooldown_time.size,
          cooldown_type: COOLDOWN_TIMES,
          cooldown_amount: cooldown_amount + 1
        )
      # 1.second, 5.days
      when ActiveSupport::Duration
        # Converts 1.second to [:seconds, 1]
        type, quantity = cooldown_time.parts.to_a.first
        update!(
          cooldown_quantity: quantity,
          cooldown_type: type,
          expires_at: (executed_at + cooldown_time).to_time
        )
      end
    end

    def remaining_uses
      cooldown_quantity - cooldown_amount
    end

    private

    # If the community changes the configuration for a command, this will adjust the cooldown
    # to match. Mainly used to adjust a cooldown if it was changed to a lesser time,
    # such as 24 hours to 2 seconds. The user shouldn't have to wait 24 hours when
    # the new cooldown is 2 seconds
    def adjust_for_community_changes
      return if community.nil?

      configuration = load_configuration
      return if configuration_unchanged?(configuration)

      update_cooldown_settings!(configuration)
    end

    def load_configuration
      case type
      when COMMAND
        community.command_configurations.find_by(command_name: key)
      when REWARD
        server.server_rewards.find_by(reward_id: key)
      end
    end

    def configuration_unchanged?(configuration)
      return true if configuration.nil?

      configuration.cooldown_type == cooldown_type &&
        configuration.cooldown_quantity == cooldown_quantity
    end

    def update_cooldown_settings!(configuration)
      if times_based_cooldown_changed?(configuration)
        reset_cooldown
      else
        adjust_expiry_time(configuration)
      end

      self.cooldown_type = configuration.cooldown_type
      self.cooldown_quantity = configuration.cooldown_quantity

      save!
    end

    def times_based_cooldown_changed?(configuration)
      configuration.cooldown_type == COOLDOWN_TIMES ||
        (configuration.cooldown_type != COOLDOWN_TIMES && cooldown_type == COOLDOWN_TIMES)
    end

    def reset_cooldown
      self.expires_at = 2.seconds.ago
      self.cooldown_amount = 0
    end

    def convert_to_seconds(quantity, type)
      quantity.send(type).to_i
    end

    def adjust_expiry_time(configuration)
      new_seconds = convert_to_seconds(configuration.cooldown_quantity, configuration.cooldown_type)
      current_seconds = convert_to_seconds(cooldown_quantity, cooldown_type)
      return if new_seconds >= current_seconds

      self.expires_at = expires_at - (current_seconds - new_seconds)
    end
  end
end
