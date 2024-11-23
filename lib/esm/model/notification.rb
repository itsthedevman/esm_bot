# frozen_string_literal: true

module ESM
  class Notification < ApplicationRecord
    DEFAULTS = YAML.safe_load_file(File.expand_path("config/notifications.yml")).freeze

    attribute :community_id, :integer
    attribute :notification_type, :string
    attribute :notification_title, :text
    attribute :notification_description, :text
    attribute :notification_color, :string
    attribute :notification_category, :string
    attribute :created_at, :datetime
    attribute :updated_at, :datetime

    belongs_to :community

    def self.build_random(community_id:, type:, category:, **)
      notification = where(
        community_id: community_id,
        notification_type: type,
        notification_category: category
      ).sample

      # Grab a default if one was not found
      if notification.nil?
        default = DEFAULTS[category]
          .select { |n| n["type"] == type }
          .sample
          .transform_keys { |k| "notification_#{k}" }

        notification = new(default)
      end

      notification.build_embed(**)
    end

    def build_embed(**templates)
      ESM::Embed.build do |e|
        e.title = format(notification_title, templates) if notification_title.present?
        e.description = format(notification_description, templates) if notification_description.present?

        e.color =
          if notification_color == "random"
            ESM::Color.random
          else
            notification_color
          end
      end
    end

    private

    # Replaces template keys with their values
    def format(string, templates)
      templates.each do |key, value|
        string = string.gsub(/{{\s*#{key}\s*}}/i, value.to_s)
      end

      string
    end
  end
end
