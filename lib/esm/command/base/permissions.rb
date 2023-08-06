# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Permissions
        def community_permissions?
          # Caching so if community_permissions returns `nil`, it doesn't hit the database for every call to this method
          @community_permission_predicate ||= !community_permissions.nil?
        end

        def cooldown_time
          if community_permissions?
            # [2, "seconds"] -> 2 seconds
            # Calls .seconds, .days, .months, etc
            community_permissions.cooldown_quantity.send(community_permissions.cooldown_type)
          else
            attributes.cooldown_time&.default || 2.seconds
          end
        end

        def enabled?
          if community_permissions?
            community_permissions.enabled?
          else
            attributes.enabled&.default || true
          end
        end

        def notify_when_disabled?
          if community_permissions?
            community_permissions.notify_when_disabled?
          else
            true
          end
        end

        def whitelisted?
          whitelist_enabled =
            if community_permissions?
              community_permissions.whitelist_enabled?
            else
              attributes.whitelist_enabled&.default || type == :admin
            end

          return true if !whitelist_enabled

          community = target_community || current_community
          return false if community.nil?

          server = ESM.bot.server(community.guild_id.to_i)
          guild_member = current_user.on(server)
          return false if guild_member.nil?

          whitelisted_role_ids =
            if community_permissions?
              community_permissions.whitelisted_role_ids
            else
              attributes.whitelisted_role_ids&.default || []
            end

          return true if guild_member.permission?(:administrator)
          return false if whitelisted_role_ids.empty?

          whitelisted_role_ids.any? { |role_id| guild_member.role?(role_id.to_i) }
        end

        # Is the command allowed in this text channel?
        def allowed?
          return true if current_channel.pm?
          return true if current_community&.player_mode_enabled?

          if community_permissions?
            community_permissions.allowed_in_text_channels?
          else
            attributes.allowed_in_text_channels&.default || true
          end
        end
      end
    end
  end
end
