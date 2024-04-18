# frozen_string_literal: true

module ESM
  module Connection
    class ConnectionManager
      def disconnect_all
        block = ->(c) { c.close("spec_finish") }

        @lobby.each(&block)
        @connections.each_value(&block)

        @lobby.clear
        @connections.clear
      end
    end
  end
end
