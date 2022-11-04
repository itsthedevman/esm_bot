# frozen_string_literal: true

module ESM
  class Connection
    class MessageOverseer
      Envelope = Struct.new(:message, :expires_at) do
        def undeliverable?
          expires_at <= ::Time.now
        end

        def delivered?
          message.delivered?
        end
      end

      attr_reader :mailbox if ESM.env.test?

      def initialize
        @mailbox = {}

        check_every = ESM.config.loops.connection_message_overseer.check_every
        @thread = Thread.new do
          loop do
            check_messages
            sleep(ESM.env.test? ? 0.5 : check_every)
          end
        end
      end

      def size
        @mailbox.size
      end

      #
      # Watches a message for a delivery response. If the message never receives one, the message's `on_error` callback will be triggered
      #
      # @param message [ESM::Connection::Message] The message to match
      # @param expires_at [DateTime, Time] The time when the message should be considered undeliverable.
      #
      def watch(message, expires_at: 10.seconds.from_now)
        # I love Ruby
        envelope = Envelope.new(message, expires_at)
        @mailbox[message.id] = envelope
      end

      #
      # Find and return a message based on its ID
      #
      # @param id [String] The ID of the message
      #
      # @return [ESM::Connection::Message, Nil] The message or nil
      #
      def retrieve(id)
        envelope = @mailbox.delete(id)
        return if envelope.nil?

        envelope.message
      end

      def remove(id)
        @mailbox.delete_if { |e| e.message.id == id }
      end

      def remove_all!(with_error: false)
        @mailbox.each do |id, envelope|
          message = envelope.message

          if with_error
            message.add_error(type: "code", content: "message_undeliverable")
            message.run_callback(:on_error, message, nil)
          end

          @mailbox.delete(id)
        end
      end

      private

      def check_messages
        # Hey look, I'm the government
        @mailbox.each do |id, envelope|
          next if !envelope.undeliverable?

          message = envelope.message
          message.add_error(type: "code", content: "message_undeliverable")
          message.run_callback(:on_error, message, nil)

          @mailbox.delete(id)
        rescue => e
          error!(error: e)

          @mailbox.delete(id)
        end
      end
    end
  end
end
