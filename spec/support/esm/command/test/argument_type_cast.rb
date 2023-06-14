# frozen_string_literal: true

module ESM
  module Command
    module Test
      class ArgumentTypeCast < ESM::Command::Base
        argument :string
        argument :integer, type: :integer
        argument :float, type: :float
        argument :json, type: :json
        argument :symbol, type: :symbol
      end
    end
  end
end
