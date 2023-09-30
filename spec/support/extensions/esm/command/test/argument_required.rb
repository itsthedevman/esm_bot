# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentRequired < TestCommand
        argument :input, required: true, description: "This is a required argument"

        use_root_namespace
      end
    end
  end
end
