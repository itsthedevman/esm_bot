# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Territory
      class Demote < ApplicationCommand
        command_type :player
        command_namespace :territory, command_name: :demote_player

        requires :registration

        argument :target, display_name: :whom
        argument :territory_id, display_name: :in
        argument :server_id, display_name: :on

        def on_execute
          # Check for registered target_user. A steam_uid is valid here so don't check ESM::User::Ephemeral
          check_registered_target_user! if target_user.is_a?(ESM::User)

          deliver!(
            function_name: "demotePlayer",
            territory_id: arguments.territory_id,
            target_uid: target_uid,
            uid: current_user.steam_uid
          )
        end

        def on_response(_, _)
          message = I18n.t(
            "commands.demote.success_message",
            user: current_user.mention,
            target_uid: target_uid,
            territory_id: arguments.territory_id,
            server: target_server.server_id
          )

          reply(ESM::Embed.build(:success, description: message))
        end
      end
    end
  end
end
