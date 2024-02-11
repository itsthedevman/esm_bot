# frozen_string_literal: true

module ESM
  module Connection
    class Client
      Error = ESM::Exception::Error

      class TimeoutError < Error
        def initialize = super("Request timed out")
      end

      class InvalidMessage < Error
        def initialize = super("Invalid message received")
      end

      class InvalidAccessKey < Error
        def initialize = super("Invalid access key")
      end
    end
  end
end
