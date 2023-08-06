# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Community
      class ResetCooldown < ESM::Command::Base
        command_type :admin
        command_namespace :community, :admin

        limit_to :text
        requires :registration

        # Skip checking for the server since this is not dependent on the server being online.
        skip_action :connected_server

        change_attribute :whitelist_enabled, default: true

        argument :target, display_name: :for
        argument :command
        argument :server_id, display_name: :on

        def on_execute
          check_owned_server! if arguments.server_id
          check_for_valid_command!
          check_registered_target_user! if target_user

          # Send the confirmation request
          reply(confirmation_embed)
          response = ESM.bot.await_response(current_user, expected: [I18n.t("yes"), I18n.t("no")], timeout: 120)
          return reply(I18n.t("commands.reset_cooldown.cancellation_reply")) if response.nil? || response.downcase == I18n.t("no").downcase

          # Reset all cooldowns for that user.
          cooldown_query.each(&:reset!)

          # Send the success message
          reply(success_embed)
        end

        def check_for_valid_command!
          return if arguments.command_name.nil?
          return if ESM::Command.include?(arguments.command_name)

          check_failed!(:invalid_command, user: current_user.mention, command_name: arguments.command_name)
        end

        def confirmation_embed
          namespace_prefix = "commands.reset_cooldown.confirmation_embed"
          ESM::Embed.build do |e|
            e.title = I18n.t("#{namespace_prefix}.title")
            description = I18n.t("#{namespace_prefix}.description.base", user: current_user.mention)

            # Change the description based on what's been requested
            # User
            description +=
              if target_user
                I18n.t("#{namespace_prefix}.description.one_user", target_user: target_user.mention)
              else
                I18n.t("#{namespace_prefix}.description.all_users")
              end

            # Command
            description +=
              if arguments.command_name
                I18n.t("#{namespace_prefix}.description.one_command", command_name: arguments.command_name)
              else
                I18n.t("#{namespace_prefix}.description.all_commands")
              end

            # Server
            description +=
              if arguments.server_id
                I18n.t("#{namespace_prefix}.description.one_server", server_id: arguments.server_id)
              else
                I18n.t("#{namespace_prefix}.description.all_servers")
              end

            e.description = description
            e.add_field(name: I18n.t("#{namespace_prefix}.field_name"), value: I18n.t("#{namespace_prefix}.field_value"))
          end
        end

        def cooldown_query
          query = ESM::Cooldown.where(community_id: current_community.id)
          query = query.or(ESM::Cooldown.where(user_id: target_user.id, steam_uid: target_user.steam_uid)) if target_user

          # Check for command_name and/or server_id if we've been given one
          query = query.where(command_name: arguments.command_name) if !arguments.command_name.nil?
          query = query.where(server_id: target_server.id) if !arguments.server_id.nil?

          query
        end

        def success_embed
          namespace_prefix = "commands.reset_cooldown.success_embed"

          ESM::Embed.build do |e|
            description = I18n.t("#{namespace_prefix}.description.base", user: current_user.mention)

            # Change the description based on what's been requested
            # User
            description +=
              if target_user
                I18n.t("#{namespace_prefix}.description.one_user", target_user: target_user.mention)
              else
                I18n.t("#{namespace_prefix}.description.all_users")
              end

            # Command
            description +=
              if arguments.command_name
                I18n.t("#{namespace_prefix}.description.one_command", command_name: arguments.command_name)
              else
                I18n.t("#{namespace_prefix}.description.all_commands")
              end

            # Server
            description +=
              if arguments.server_id
                I18n.t("#{namespace_prefix}.description.one_server", server_id: arguments.server_id)
              else
                I18n.t("#{namespace_prefix}.description.all_servers")
              end

            e.description = description
            e.color = :green
          end
        end
      end
    end
  end
end
