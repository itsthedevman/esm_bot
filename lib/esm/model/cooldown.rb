# frozen_string_literal: true

module ESM
  class Cooldown < ApplicationRecord
    attribute :community_id, :integer
    attribute :server_id, :integer
    attribute :user_id, :integer
    attribute :steam_uid, :string
    attribute :command_name, :string
    attribute :cooldown_quantity, :integer, default: 1
    attribute :cooldown_type, :string, default: "seconds"
    attribute :cooldown_amount, :integer, default: 0
    attribute :expires_at, :datetime, default: -> { 1.second.ago }
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :user
    belongs_to :server
    belongs_to :community

    after_find :adjust_for_community_changes

    def user
      return ESM::User.where(id: user_id).first if user_id.present?
      return ESM::User.find_by_steam_uid(steam_uid) if steam_uid.present?

      nil
    end

    def active?
      if cooldown_type == "times"
        cooldown_amount >= cooldown_quantity
      else
        expires_at >= ::Time.current
      end
    end

    def to_s
      ESM::Time.distance_of_time_in_words(expires_at)
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
          cooldown_type: "times",
          cooldown_amount: cooldown_amount + 1
        )
      # 1.second, 5.days
      when ActiveSupport::Duration
        # Converts 1.second to [:seconds, 1]
        type, quantity = cooldown_time.parts.to_a.first
        update!(cooldown_quantity: quantity, cooldown_type: type, expires_at: (executed_at + cooldown_time).to_time)
      end
    end

    private

    # If the community changes the configuration for a command, this will adjust the cooldown to match.
    # Mainly used to adjust a cooldown if it was changed to a lesser time, such as 24 hours to 2 seconds.
    # The user shouldn't have to wait 24 hours when the new cooldown is 2 seconds
    def adjust_for_community_changes
      # Commands that have no community_id and are used in DMs will not be able to use this code
      return if community.nil?

      configuration = community.command_configurations.where(command_name: command_name).first
      return if configuration.nil?
      return if configuration.cooldown_type == cooldown_type && configuration.cooldown_quantity == cooldown_quantity

      # They have changed to times, just reset the cooldown_amount to 0
      # Or they have changed from times to seconds (minutes, hours, etc.)
      if configuration.cooldown_type == "times" || (configuration.cooldown_type != "times" && cooldown_type == "times")
        self.expires_at = 1.second.ago
        self.cooldown_amount = 0
      else
        # Converts 1, "minutes" to 1.minutes to 60 (seconds)
        new_cooldown_seconds = configuration.cooldown_quantity.send(configuration.cooldown_type).to_i
        current_cooldown_seconds = cooldown_quantity.send(cooldown_type).to_i

        # Adjust the expiry time to compensate if the new time is less than the current
        self.expires_at = expires_at - (current_cooldown_seconds - new_cooldown_seconds) if new_cooldown_seconds < current_cooldown_seconds
      end

      self.cooldown_type = configuration.cooldown_type
      self.cooldown_quantity = configuration.cooldown_quantity
      save!
    end
  end
end
