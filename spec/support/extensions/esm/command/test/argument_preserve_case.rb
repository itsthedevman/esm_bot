# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentPreserveCase < TestCommand
        argument :input, preserve_case: true
      end
    end
  end
end
