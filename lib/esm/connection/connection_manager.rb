# frozen_string_literal: true

module ESM
  module Connection
    class ConnectionManager
      def initialize(lobby_timeout)
        @lobby_timeout = lobby_timeout

        @connections = Concurrent::Map.new
        @lobby = Concurrent::Array.new
      end

      def find(id)
        @connections[id]
      end

      def on_connect(socket)
        @lobby << Client.new(socket)
      end

      def on_authentication(client)
        @lobby.delete(client)
        @connections[client.id] = client
      end

      def on_disconnect(client)
        @connections.delete(client.id)
      end

      private

      def check_lobby
        @lobby.delete_if do |client|
          timed_out = (Time.current - client.connected_at) >= @lobby_timeout
          next false unless timed_out

          client.close("Failed to authenticate before timeout")
          true
        end
      end
    end
  end
end
