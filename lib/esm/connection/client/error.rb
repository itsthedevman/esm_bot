# frozen_string_literal: true

module ESM
  module Connection
    class Client
      Error = ESM::Exception::Error

      class NotAuthorized < Error
        def initialize
          super("Failed authorization")
        end
      end

      class TimeoutError < Error
        def initialize
          super("Request timed out")
        end
      end
    end
  end
end
