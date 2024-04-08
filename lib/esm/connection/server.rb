# frozen_string_literal: true

module ESM
  module Connection
    class Server
      def initialize
        @config = ESM.config.connection_server
        @connections = Concurrent::Map.new
        @waiting_room = WaitingRoom.new
        @server = Socket.new(TCPServer.new("0.0.0.0", ESM.config.ports.connection_server))
      end

      def start
        start_connect_task
        start_disconnect_task

        info!(status: :started)
      end

      def stop
        cleanup_tasks

        @connections.each_value { |client| client.close("Server shutdown") }
        @connections.clear

        @waiting_room.shutdown
        @waiting_room.clear

        @server&.shutdown(:RDWR)
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

      def start_connect_task
        @connect_task = Concurrent::TimerTask.execute(execution_interval: @config.connection_check) do
          on_connect
        end
      end

      def start_disconnect_task
        @disconnect_task = Concurrent::TimerTask.execute(execution_interval: @config.waiting_room_check) do
          check_waiting_room
        end
      end

      def cleanup_tasks
        @connect_task&.shutdown
        @connect_task = nil

        @disconnect_task&.shutdown
        @disconnect_task = nil
      end

      def on_connect
        socket = @server.accept
        return unless socket.is_a?(TCPSocket)

        @waiting_room << Client.new(self, socket)
      rescue => e
        error!(error: e)
      end

      def check_waiting_room
        @waiting_room.delete_if do |entry|
          timed_out = (Time.current - entry.connected_at) >= @config.disconnect_after
          next false unless timed_out

          entry.client.close("Waiting room timeout")
          true
        end
      end
    end
  end
end
