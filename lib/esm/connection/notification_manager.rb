# frozen_string_literal: true

module ESM
  module Connection
    class NotificationManager
      include Singleton

      attr_reader :queue

      def self.add(notifications)
        notifications.each { |n| instance.queue.push(n) }
      end

      def initialize(execution_interval: 0.5)
        @queue = Queue.new
        @task = Concurrent::TimerTask.execute(execution_interval:) { process_next }
      end

      private

      def process_next
        notification = @queue.pop(timeout: 0)
        return if notification.nil?

        notification.send_to_recipients
      end
    end
  end
end
