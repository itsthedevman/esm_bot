# frozen_string_literal: true

module ESM
  module Command
    module My
      class Aliases < ApplicationCommand
        #################################
        #
        # Configuration
        #

        change_attribute :allowlist_enabled, modifiable: false
        change_attribute :allowlisted_role_ids, modifiable: false

        command_type :player

        #################################

        def on_execute
          embed =
            ESM::Embed.build do |e|
              e.title = "My aliases"

              description = ""
              aliases = current_user.id_aliases.by_type

              if (id_aliases = aliases[:community]) && id_aliases.size > 0
                description += "**Communities**\n```#{build_table("Community", id_aliases)}```\n"
              end

              if (id_aliases = aliases[:server]) && id_aliases.size > 0
                description += "**Servers**\n```#{build_table("Server", id_aliases)}```\n"
              end

              description = "You do not have any aliases, yet. " if description.blank?
              description += "*Aliases can be managed from the [player dashboard](https://esmbot.com/users/#{current_user.discord_id}/edit#id_aliases)*"

              e.description = description
            end

          reply(embed)
        end

        private

        def build_table(type, id_aliases)
          table = Terminal::Table.new(
            headings: ["Alias", "#{type} ID", "#{type} name"],
            style: {border: :unicode_round}
          )

          id_aliases.each do |id_alias|
            if id_alias.server_id
              server = id_alias.server
              id = server.server_id
              name = server.server_name
            else
              community = id_alias.community
              id = community.community_id
              name = community.community_name
            end

            table << [id_alias.value, id, name.truncate(20)]
          end

          table.to_s
        end
      end
    end
  end
end
