# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class Pay < ApplicationCommand
        command_type :player

        requires :registration

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
