# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Uptime < ESM::Command::Base
        command_type :player

        argument :server_id, display_name: :for

        def on_execute
          embed =
            ESM::Embed.build do |e|
              e.description = I18n.t("commands.uptime.server_uptime", server: target_server.server_id, time: target_server.uptime)
            end

          reply(embed)
        end
      end
    end
  end
end
