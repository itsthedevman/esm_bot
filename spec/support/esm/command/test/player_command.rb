# frozen_string_literal: true

module ESM
  module Command
    module Test
      class PlayerCommand < ESM::Command::Base
        command_type :player

        def on_execute
          "on_execute"
        end

        def on_response(_, _)
          "on_response"
        end
      end
    end
  end
end
