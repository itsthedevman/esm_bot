# frozen_string_literal: true

module ESM
  module Connection
    class ConnectionManager
      def initialize(lobby_timeout)
        @lobby_timeout = lobby_timeout

        @connections = Concurrent::Map.new
        @lobby = Concurrent::Array.new
        @task = Concurrent::TimerTask.execute(execution_interval: 1) { check_lobby }
      end

      def find(id)
        @connections[id]
      end

      def on_connect(socket)
        @lobby << Client.new(socket)
      end

      def on_initialize(client)
        @lobby.delete(client)
        @connections[client.public_id] = client
      end

      def on_disconnect(client)
        @lobby.delete(client)
        @connections.delete(client.public_id)
      end

      private

      def check_lobby
        @lobby.delete_if do |client|
          timed_out = (Time.current - client.connected_at) >= @lobby_timeout
          next false unless timed_out

          client.close
          true
        end
      end
    end
  end
end
