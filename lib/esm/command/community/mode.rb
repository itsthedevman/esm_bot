# frozen_string_literal: true

module ESM
  module Command
    module Community
      class Mode < ESM::Command::Base
        command_type :admin
        command_namespace :community, :admin, command_name: :change_mode

        limit_to :dm

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: false
        define :cooldown_time, modifiable: false, default: 2.seconds

        argument :community_id, display_name: :for

        def on_execute
          check_for_owner!
          check_for_active_servers! if enable_player_mode?

          # Flip it, flip it good
          target_community.update!(player_mode_enabled: enable_player_mode?)

          # Reply back
          embed =
            ESM::Embed.build do |e|
              e.description = I18n.t(
                "commands.mode.#{enable_player_mode ? "enabled" : "disabled"}",
                community_name: target_community.name
              )
              e.color = :green
            end

          reply(embed)
        end

        private

        # Attempt to flip the value and see what happens :D
        def enable_player_mode?
          @enable_player_mode ||= !target_community.player_mode_enabled?
        end

        def check_for_active_servers!
          check_failed!(:servers_exist, user: current_user.mention) if target_community.servers.any?
        end
      end
    end
  end
end
