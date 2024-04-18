# frozen_string_literal: true

module ESM
  module Connection
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
  end
end
