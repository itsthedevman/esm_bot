# frozen_string_literal: true

module ESM
  module Command
    module Test
      class SkipServerCheckCommand < ESM::Command::Base
        command_type :player

        skip_action :connected_server

        argument :server_id

        def on_execute
          "Hello"
        end

        def on_response(_, _)
        end
      end
    end
  end
end
