# frozen_string_literal: true

module ESM
  module Command
    module My
      class SteamUid < ApplicationCommand
        #################################
        #
        # Configuration
        #

        change_attribute :enabled, modifiable: false
        change_attribute :whitelist_enabled, modifiable: false
        change_attribute :whitelisted_role_ids, modifiable: false

        command_type :player

        #################################

        def on_execute
          embed =
            ESM::Embed.build do |e|
              e.description = I18n.t("commands.steam_uid.response", user: current_user.mention, steam_uid: current_user.steam_uid)
            end

          reply(embed)
        end
      end
    end
  end
end
