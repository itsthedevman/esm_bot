# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentPreserveCase < ApplicationCommand
        argument :input, preserve: true
      end
    end
  end
end
