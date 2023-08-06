# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Player < ESM::Command::Base
        command_type :admin
        command_namespace :server, :admin, command_name: :modify_player

        limit_to :text
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :target, display_name: :whom
        argument :action, required: true, checked_against: /m(?:oney)?|r(?:espect)?|l(?:ocker)?|h(?:eal)?|k(?:ill)?/
        argument :server_id, display_name: :on
        argument(:amount, type: :integer, checked_against: /-?\d+/,
          modifier: lambda do |argument|
            return unless arguments.type&.match(/h(?:eal)?|k(?:ill)?/i)

            # The types `heal` and `kill` don't require the value argument.
            argument.content = nil
          end)

        def on_execute
          check_registered_target_user! if target_user.is_a?(ESM::User)

          deliver!(
            function_name: "modifyPlayer",
            discord_tag: current_user.mention,
            target_uid: target_uid,
            type: expanded_action,
            value: arguments.amount
          )
        end

        def on_response(_, _)
          embed = ESM::Notification.build_random(
            community_id: target_community.id,
            type: expanded_action,
            category: "player",
            serverid: target_server.server_id,
            servername: target_server.server_name,
            communityid: target_community.community_id,
            username: current_user.username,
            usertag: current_user.mention,
            targetusername: target_user.username,
            targetusertag: target_user.mention,
            targetuid: target_uid,
            modifiedamount: @response.modified_amount&.to_readable,
            previousamount: @response.previous_amount&.to_readable,
            newamount: @response.new_amount&.to_readable
          )

          reply(embed)
        end

        private

        def expanded_action
          @expanded_action ||= lambda do
            case arguments.action
            when "m"
              "money"
            when "r"
              "respect"
            when "l"
              "locker"
            when "h"
              "heal"
            when "k"
              "kill"
            else
              arguments.action
            end
          end.call
        end
      end
    end
  end
end
