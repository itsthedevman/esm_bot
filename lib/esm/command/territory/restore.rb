# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Territory
      class Restore < ESM::Command::Base
        command_type :admin
        command_namespace :territory, :admin

        limit_to :text
        requires :registration

        change_attribute :whitelist_enabled, default: true

        argument :territory_id, display_name: :territory
        argument :server_id, display_name: :on

        def on_execute
          check_owned_server!
          deliver!(query: "restore", territory_id: arguments.territory_id)
        end

        def on_response(_, _)
          embed =
            if @response.success
              ESM::Embed.build(
                :success,
                description: I18n.t("commands.restore.success_message", user: current_user.mention, territory_id: arguments.territory_id)
              )
            else
              ESM::Embed.build(
                :error,
                description: I18n.t(
                  "commands.restore.failure_message",
                  user: current_user.mention,
                  territory_id: arguments.territory_id,
                  server: target_server.server_id
                )
              )

            end

          reply(embed)
        end
      end
    end
  end
end
