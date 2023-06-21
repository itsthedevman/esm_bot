# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentPreserveCase < ESM::Command::Base
        argument :input, preserve: true
      end
    end
  end
end
