# frozen_string_literal: true

module ESM
  module Command
    module Community
      class Id < ApplicationCommand
        #################################
        #
        # Configuration
        #

        change_attribute :allowed_in_text_channels, modifiable: false
        change_attribute :cooldown_time, modifiable: false
        change_attribute :enabled, modifiable: false
        change_attribute :whitelist_enabled, modifiable: false
        change_attribute :whitelisted_role_ids, modifiable: false

        command_type :player

        limit_to :text

        #################################

        def on_execute
          embed =
            ESM::Embed.build do |e|
              e.description = I18n.t("commands.id.embed.description", community_name: current_community.name, community_id: current_community.community_id)
              e.add_field(
                name: I18n.t("commands.id.embed.field.name"),
                value: I18n.t("commands.id.embed.field.value", community_id: current_community.community_id)
              )
            end

          reply(embed)
        end
      end
    end
  end
end
