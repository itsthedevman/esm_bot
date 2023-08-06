# frozen_string_literal: true

module ESM
  module Command
    module Test
      class SkipCooldownCommand < ESM::Command::Base
        command_type :player

        def on_execute
          skip_action(:cooldown)
        end

        def on_response(_, _)
        end
      end
    end
  end
end
