# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentRequired < ApplicationCommand
        argument :input, description: "This argument is required"
      end
    end
  end
end
