# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Player < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::DEFAULTS[:target]
        argument :target, display_name: :whom

        # Required: Needed by command
        argument :action, required: true, checked_against: /m(?:oney)?|r(?:espect)?|l(?:ocker)?|h(?:eal)?|k(?:ill)?/

        # See Argument::DEFAULTS[:server_id]
        argument :server_id, display_name: :on

        # Optional: Not required by heal or kill
        argument(
          :amount,
          type: :integer,
          checked_against: /-?\d+/,
          modifier: lambda do |argument|
            return unless arguments.type&.match(/h(?:eal)?|k(?:ill)?/i)

            # The types `heal` and `kill` don't require the value argument.
            argument.content = nil
          end
        )

        #
        # Configuration
        #

        change_attribute :whitelist_enabled, default: true

        command_namespace :server, :admin, command_name: :modify_player
        command_type :admin

        limit_to :text

        #################################

        def on_execute
          check_for_registered_target_user! if target_user.is_a?(ESM::User)

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
