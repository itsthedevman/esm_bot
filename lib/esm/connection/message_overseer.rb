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

      def watch(message)
        # I love Ruby
        envelope = Envelope.new(message, 30.seconds.from_now)
        @mailbox << envelope
      end

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
        end
      end
    end
  end
end
