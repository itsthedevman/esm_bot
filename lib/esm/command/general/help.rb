# frozen_string_literal: true

module ESM
  module Command
    module General
      class Help < ESM::Command::Base
        command_type :player
        use_root_namespace

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        argument :category, regex: /.*/, default: nil

        def on_execute
          case @arguments.category
          when "commands"
            commands
          when "player commands"
            commands(types: [:player], include_development: false)
          when "admin commands"
            commands(types: [:admin], include_development: false)
          when ->(category) { ESM::Command.include?(category) }
            command
          else
            getting_started
          end
        end

        #########################
        # Command Methods
        #########################
        def getting_started
          embed =
            ESM::Embed.build do |e|
              e.title = I18n.t("commands.help.getting_started.title", user: current_user.username)

              commands_by_type = ESM::Command.by_type
              e.description = I18n.t(
                "commands.help.getting_started.description",
                command_count_player: commands_by_type[:player].size,
                command_count_total: commands_by_type.values.flatten.size
              )

              # history
              %w[commands command privacy].each do |field_type|
                e.add_field(
                  name: I18n.t("commands.help.getting_started.fields.#{field_type}.name"),
                  value: I18n.t("commands.help.getting_started.fields.#{field_type}.value")
                )
              end
            end

          reply(embed)
        end

        def commands(types: ESM::Command::TYPES.dup, include_development: ESM.env.development?)
          types << :development if include_development

          # Remove :admin if player mode is enabled for this community
          types.delete(:admin) if current_community&.player_mode_enabled?

          # Now build the embed for each type
          types.each do |type|
            next if categories(type).blank?

            embed =
              ESM::Embed.build do |e|
                e.title = I18n.t("commands.help.commands.#{type}.title")
                e.description = I18n.t("commands.help.commands.#{type}.description")
                e.color = ESM::Color.random

                categories(type).each do |category, commands|
                  e.add_field(
                    name: "**__#{category.humanize}__**",
                    value: format_commands(commands)
                  )
                end
              end

            reply(embed)
          end
        end

        def categories(type)
          return [] if ESM::Command.by_type[type].nil?

          ESM::Command.by_type[type].group_by(&:category)
        end

        # Return an array so ESM::Embed field logic will handle overflow correctly
        def format_commands(commands)
          commands.sort_by(&:usage).map do |command|
            description = command.description
            description += "\n#{command.description_extra}" if command.description_extra.present?

            "**`#{command.usage}`**\n#{description}"
          end
        end

        def command
          command = ESM::Command[@arguments.category].new
          embed =
            ESM::Embed.build do |e|
              e.title = I18n.t("commands.help.command.title", name: command.usage(with_args: false))
              description = ["_This command used to be `!#{command.command_name}`_", command.description, ""]

              # Adds a note about being limited to DM or Text
              description << I18n.t("commands.help.command.note") if command.limited_to || command.whitelist_enabled?
              description << I18n.t("commands.help.command.limited_to", channel_type: I18n.t(command.limited_to)) if command.limited_to
              description << I18n.t("commands.help.command.whitelist_enabled") if command.whitelist_enabled?
              e.description = description

              # Usage
              e.add_field(
                name: I18n.t("commands.help.command.usage"),
                value: "```#{command.usage}```"
              )

              # Arguments
              if command.arguments.present?
                e.add_field(
                  name: I18n.t("commands.help.command.arguments"),
                  value: command.arguments.templates.map { |_, argument| argument.help_documentation }
                )
              end

              # Examples
              if command.example.present?
                e.add_field(
                  name: I18n.t("commands.help.command.examples"),
                  value: command.example
                )
              end
            end

          reply(embed)
        end
      end
    end
  end
end
