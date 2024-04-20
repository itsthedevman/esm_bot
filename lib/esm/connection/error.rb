# frozen_string_literal: true

module ESM
  module Connection
    # Used primarily as an observer for Server and Client tasks
    class ErrorHandler
      def update(_time, _result, error)
        return if error.nil?

        error!(error:)
      end
    end

    Error = ESM::Exception::Error

    class NotConnected < Error
      def initialize(server_id = nil) = super("#{server_id || "Server"} is not connected at the moment")
    end

    class RequestTimeout < Error
      def initialize = super("Request timed out")
    end

    class ExistingConnection < Error
      def initialize = super("Client already connected")
    end

    class InvalidMessage < Error
      def initialize = super("Invalid message received")
    end

    class InvalidAccessKey < Error
      def initialize = super("Invalid access key")
    end

    class RejectedRequest < Error
      def initialize(reason = "") = super(reason)
    end

    class DecryptionError < Error
      def initialize(message = "") = super(message.presence || "Failed to decrypt")
    end

    class InvalidBase64 < DecryptionError
      def initialize = super("Invalid base64")
    end

    class InvalidSecretKey < DecryptionError
      def initialize = super("Invalid secret key")
    end

    class InvalidNonce < DecryptionError
      def initialize = super("Invalid nonce")
    end

    class ExtensionError < Error
    end
  end
end
