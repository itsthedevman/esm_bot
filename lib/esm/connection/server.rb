# frozen_string_literal: true

module ESM
  module Connection
    class Server
      def initialize
        @allow_connections = Concurrent::AtomicBoolean.new
        @config = ESM.config.connection_server

        @connections = Concurrent::Map.new
        @waiting_room = WaitingRoom.new
      end

      def allow_connections?
        @allow_connections.true?
      end

      def start
        return if allow_connections?

        @server = Socket.new(TCPServer.new("0.0.0.0", ESM.config.ports.connection_server))
        @allow_connections.make_true

        @connect_task = Concurrent::TimerTask.execute(execution_interval: @config.connection_check) do
          on_connect
        end

        @disconnect_task = Concurrent::TimerTask.execute(execution_interval: @config.waiting_room_check) do
          check_waiting_room
        end

        info!(status: :started)
      end

      def stop
        return unless allow_connections?

        @allow_connections.make_false

        @connect_task.shutdown
        @connect_task = nil

        @disconnect_task.shutdown
        @disconnect_task = nil

        @connections.each_value { |client| client.close("shutdown") }
        @connections.clear

        @waiting_room.shutdown
        @waiting_room.clear

        @server.shutdown(:RDWR)
      end

      def client(id)
        @connections[id]
      end

      def client_connected(client)
        @waiting_room.delete(client)
        @connections[client.id] = client
      end

      def client_disconnected(client)
        @waiting_room.delete(client)
        @connections.delete(client.id) if client.id
      end

      private

      def on_connect
        return unless allow_connections?

        @waiting_room << Client.new(self, @server.accept)
      end

      def check_waiting_room
        @waiting_room.delete_if do |entry|
          timed_out = (Time.current - entry.connected_at) >= @config.disconnect_after
          next false unless timed_out

          entry.client.close
          true
        end
      end
    end
  end
end
