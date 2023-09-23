# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Metadata
        def to_h
          {
            name: name,
            arguments: arguments,
            current_community: current_community&.attributes,
            current_channel: current_channel.inspect,
            current_user: current_user.inspect,
            current_cooldown: current_cooldown&.attributes,
            target_community: target_community&.attributes,
            target_server: target_server&.attributes,
            target_user: target_user.respond_to?(:attributes) ? target_user.attributes : target_user.inspect,
            target_uid: target_uid,
            same_user: same_user?,
            dm_only: dm_only?,
            text_only: text_only?,
            dev_only: dev_only?,
            registration_required: registration_required?,
            on_cooldown: on_cooldown?,
            permissions: {
              config: community_permissions&.attributes,
              allowlist_enabled: command_allowlist_enabled?,
              enabled: command_enabled?,
              allowed: command_allowed_in_channel?,
              allowlisted: command_allowed?,
              notify_when_disabled: notify_when_command_disabled?,
              cooldown_time: cooldown_time
            }
          }
        end

        def inspect
          "<#{self.class.name} #{ESM::JSON.pretty_generate(to_h)}>"
        end
      end
    end
  end
end
