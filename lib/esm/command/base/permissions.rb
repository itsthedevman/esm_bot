# frozen_string_literal: true

module ESM
  module Command
    class Base
      class Permissions
        def initialize(command)
          @command = command
          @config = nil
        end

        def load
          return if @config

          community = @command.target_community || @command.current_community
          if community.nil?
            # Performing a validation check on these arguments because this happens before the command
            # does the validation
            argument = @command.arguments.get(:server_id) || @command.arguments.get(:community_id)
            @command.arguments.invalid_argument!(argument) if argument&.invalid?
          end

          @config = community&.command_configurations&.where(command_name: @command.name)&.first
        end

        def config_present?
          @config.present?
        end

        def cooldown_time
          if config_present?
            # [2, "seconds"] -> 2 seconds
            # Calls .seconds, .days, .months, etc
            @config.cooldown_quantity.send(@config.cooldown_type)
          else
            @command.defines.cooldown_time&.default || 2.seconds
          end
        end

        def enabled?
          if config_present?
            @config.enabled?
          else
            @command.defines.enabled&.default || true
          end
        end

        def notify_when_disabled?
          if config_present?
            @config.notify_when_disabled?
          else
            true
          end
        end

        def whitelisted?
          whitelist_enabled =
            if config_present?
              @config.whitelist_enabled?
            else
              @command.defines.whitelist_enabled&.default || @command.type == :admin
            end

          return true if !whitelist_enabled

          community = @command.target_community || @command.current_community
          return false if community.nil?

          server = ESM.bot.server(community.guild_id.to_i)
          guild_member = @command.current_user.on(server)
          return false if guild_member.nil?

          whitelisted_role_ids =
            if config_present?
              @config.whitelisted_role_ids
            else
              @command.defines.whitelisted_role_ids&.default || []
            end

          return true if guild_member.permission?(:administrator)
          return false if whitelisted_role_ids.empty?

          whitelisted_role_ids.any? { |role_id| guild_member.role?(role_id.to_i) }
        end

        # Is the command allowed in this text channel?
        def allowed?
          return true if @command.event.channel.pm?
          return true if @command.current_community&.player_mode_enabled?

          if config_present?
            @config.allowed_in_text_channels?
          else
            @command.defines.allowed_in_text_channels&.default || true
          end
        end

        def to_h
          {
            config: @config&.attributes,
            enabled: enabled?,
            allowed: allowed?,
            whitelisted: whitelisted?,
            notify_when_disabled: notify_when_disabled?,
            cooldown_time: cooldown_time
          }
        end
      end
    end
  end
end
