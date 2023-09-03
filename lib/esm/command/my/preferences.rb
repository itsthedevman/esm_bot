# frozen_string_literal: true

module ESM
  module Command
    module My
      class Preferences < ApplicationCommand
        TYPES = %w[
          all
          custom
          base_raid
          flag_stolen
          flag_restored
          flag_steal_started
          protection_money_due
          protection_money_paid
          grind_started
          hack_started
          charge_plant_started
          marxet_item_sold
        ].freeze

        command_type :player

        limit_to :dm
        requires :registration

        # This command is not dependent on the server being connected
        skip_action :connected_server

        change_attribute :enabled, modifiable: false
        change_attribute :whitelist_enabled, modifiable: false
        change_attribute :whitelisted_role_ids, modifiable: false
        change_attribute :allowed_in_text_channels, modifiable: false
        change_attribute :cooldown_time, modifiable: false

        argument :server_id, display_name: :for
        argument :action, choices: {allow: "Allow", deny: "Block"}
        argument :type, choices: TYPES.each_with_object({}) { |t, h| h[t] = t.titleize.humanize }

        def on_execute
          return send_preferences if arguments.action.nil?

          # Creates an array of ["custom"] or ["base-raid", "flag-stolen", "flag-restored", etc...]
          types =
            if arguments.type == "all"
              # Remove "all" from the list
              TYPES.dup[1..]
            else
              [arguments.type]
            end

          # Converts the array of types to { custom: true }, or { "base-raid": false, "flag-stolen": false, "flag-restored": false, etc... }
          query = types.map { |type| [type, allowed?] }.to_h

          # Update the preference
          preference.update(query)

          reply(
            ESM::Embed.build(:success, description: ":white_check_mark: Your preferences for `#{target_server.server_id}` have been updated")
          )
        end

        def preference
          @preference ||= ESM::UserNotificationPreference.where(user_id: current_user.id, server_id: target_server.id).first_or_create
        end

        def allowed?
          @allowed ||= arguments.action == "allow"
        end

        def send_preferences
          embed =
            ESM::Embed.build do |e|
              e.title = "Notification preferences for `#{target_server.server_id}`"
              e.description =
                preference.attributes.format(join_with: "\n") do |key, value|
                  next if %w[id user_id server_id created_at updated_at deleted_at].include?(key)

                  "#{value ? ":white_check_mark:" : ":x:"} **#{key.humanize}**"
                end
            end

          reply(embed)
        end
      end
    end
  end
end
