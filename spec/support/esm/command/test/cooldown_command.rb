# frozen_string_literal: true

module ESM
  module Command
    module Test
      class CooldownCommand < ESM::Command::Base
        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 10.seconds

        def on_execute
        end

        def on_response(_, _)
        end
      end
    end
  end
end