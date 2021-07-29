# frozen_string_literal: true

module ESM
  class Connection
    class MessageOverseer
      Envelope = Struct.new(:message, :expires_at) do
        def undeliverable?
          self.expires_at <= ::Time.now
        end

        def delivered?
          self.message.delivered?
        end
      end

      def initialize
        @mailbox = []

        check_every = ESM.config.loops.connection_message_overseer.check_every
        @thread = Thread.new do
          loop do
            check_messages
            sleep(ESM.env.test? ? 0.5 : check_every)
          end
        end
      end

      #
      # Watches a message for a delivery response. If the message never receives one, the message's `on_error` callback will be triggered
      #
      # @param message [ESM::Connection::Message] The message to match
      # @param expires_at [DateTime, Time] The time when the message should be considered undeliverable.
      #
      def watch(message, expires_at: 30.seconds.from_now)
        # I love Ruby
        envelope = Envelope.new(message, expires_at)
        @mailbox << envelope
      end

      #
      # Find and return a message based on its ID
      #
      # @param id [String] The ID of the message
      #
      # @return [ESM::Connection::Message, Nil] The message or nil
      #
      def retrieve(id)
        @mailbox.find { |envelope| envelope.message.id == id }.try(:message)
      end

      private

      def check_messages
        # Hey look, I'm the government
        @mailbox.each do |envelope|
          next @mailbox.delete(envelope) if envelope.delivered?
          next if !envelope.undeliverable?

          message = envelope.message
          message.add_error(type: "code", content: "message_undeliverable")
          message.run_callback(:on_error, message, nil)

          @mailbox.delete(envelope)
        rescue StandardError => e
          ESM::Notifications.trigger("error", class: self.class, method: __method__, error: e)

          @mailbox.delete(envelope)
        end
      end
    end
  end
end
