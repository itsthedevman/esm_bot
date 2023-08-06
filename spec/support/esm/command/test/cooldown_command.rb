# frozen_string_literal: true

module ESM
  module Command
    module Test
      class CooldownCommand < ESM::Command::Base
        change_attribute :cooldown_time, default: 10.seconds

        def on_execute
        end

        def on_response(_, _)
        end
      end
    end
  end
end
