# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentAlias < ESM::Command::Base
        register_aliases :alias_argument # Reversed name
      end
    end
  end
end
