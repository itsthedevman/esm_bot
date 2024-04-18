# frozen_string_literal: true

module ESM
  module Connection
    class MessageProcessor
      def initialize
        @encryption_enabled = false
        @queue = Thread::Queue.new
      end

      def on_message(data)
      end

      private

      def process_next
        data = @queue.pop


      end
    end
  end
end
