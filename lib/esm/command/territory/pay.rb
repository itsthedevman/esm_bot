# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class Pay < ESM::Command::Base
        command_type :player

        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :territory_id, display_name: :territory
        argument :server_id, display_name: :on

        def on_execute
          deliver!(function_name: "payTerritory", territory_id: arguments.territory_id, uid: current_user.steam_uid)
        end

        def on_response(_, _)
          embed =
            ESM::Embed.build do |e|
              e.description = I18n.t(
                "commands.pay.embed.description",
                user: current_user.mention,
                server_id: target_server.server_id,
                territory_id: arguments.territory_id,
                cost: @response.payment.to_poptab,
                locker_amount: @response.locker.to_poptab
              )

              e.color = :green
            end

          reply(embed)
        end
      end
    end
  end
end
