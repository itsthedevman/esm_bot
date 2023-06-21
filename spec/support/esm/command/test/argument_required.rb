# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentRequired < ESM::Command::Base
        argument :input, description: "This argument is required"
      end
    end
  end
end
