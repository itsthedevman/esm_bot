# frozen_string_literal: true

module ESM
  class Test
    class Messages < Array
      def store(message, channel)
        # Don't break tests
        self << [channel, message]

        message
      end
    end
  end
end
