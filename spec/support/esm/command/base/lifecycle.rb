# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Lifecycle
        alias_method :old_handle_error, :handle_error

        def handle_error(error, raise_error: true)
          raise error if raise_error # So tests can check for errors

          old_handle_error
        end
      end
    end
  end
end
