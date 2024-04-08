# frozen_string_literal: true

module ESM
  module Connection
    class Server
      attr_reader :waiting_room, :connections

      def pause
        cleanup_tasks

        reset_connections
      end

      def resume
        reset_connections

        start_connect_task
        start_disconnect_task
      end

      def reset_connections
        @connections.each_value { |client| client.close("spec finish") }
        @waiting_room.shutdown
        @connections.clear
        @waiting_room.clear
      end
    end
  end
end
