# frozen_string_literal: true

module ESM
  module Command
    class Argument
      def initialize(...)
        super(...)
      rescue ArgumentError
        # I'm not fully sure that this is what I want to do, but it does keep me from having to define a description on every test argument
        @description = "Testing"
      end
    end
  end
end
