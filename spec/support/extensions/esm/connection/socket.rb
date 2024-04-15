# frozen_string_literal: true

module ESM
  module Connection
    class Socket
      def blocker
        @blocker ||= Concurrent::AtomicBoolean.new
      end

      def block!
        blocker.make_true
      end

      def unblock!
        blocker.make_false
      end

      alias_method :p_acceptable?, :acceptable?
      def acceptable?(...)
        blocker.false? && p_acceptable?(...)
      end
    end
  end
end
