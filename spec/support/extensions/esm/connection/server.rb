# frozen_string_literal: true

module ESM
  module Connection
    class Server
      attr_reader :waiting_room, :connections

      def pause
        reset_connections
        @allow_connections.make_false
      end

      def resume
        reset_connections
        @allow_connections.make_true
      end

      def reset_connections
        @connections.each_value { |client| client.close("shutdown") }
        @waiting_room.shutdown

        @connections.clear
        @waiting_room.clear
      end
    end
  end
end
