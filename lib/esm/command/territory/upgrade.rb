# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Territory
      class Upgrade < ESM::Command::Base
        command_type :player

        requires :registration

        argument :territory_id, display_name: :territory
        argument :server_id, display_name: :on

        def on_execute
          deliver!(
            function_name: "upgradeTerritory",
            territory_id: arguments.territory_id,
            uid: current_user.steam_uid
          )
        end

        def on_response(_, _)
          return if @response.blank?

          message = I18n.t(
            "commands.upgrade.success_message",
            user: current_user.mention,
            territory_id: arguments.territory_id,
            cost: @response.cost.to_poptab,
            level: @response.level,
            range: @response.range,
            locker: @response.locker.to_poptab
          )

          reply(ESM::Embed.build(:success, description: message))
        end
      end
    end
  end
end
