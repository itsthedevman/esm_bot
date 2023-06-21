# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentDefault < ESM::Command::Base
        argument :input, default: "default success!"
      end
    end
  end
end
