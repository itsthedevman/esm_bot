# frozen_string_literal: true

module ESM
  module Command
    module Test
      class TargetCommand < ESM::Command::Base
        command_type :player

        argument :target

        def on_execute
        end

        def on_response(_, _)
        end
      end
    end
  end
end
