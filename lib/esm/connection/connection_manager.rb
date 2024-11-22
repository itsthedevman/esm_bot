# frozen_string_literal: true

module ESM
  module Connection
    class ConnectionManager
      def initialize(lobby_timeout: 1, heartbeat_timeout: 5, execution_interval: 1)
        @lobby_timeout = lobby_timeout
        @heartbeat_timeout = heartbeat_timeout

        @lobby = Concurrent::Array.new
        @lobby_task = Concurrent::TimerTask.execute(execution_interval:) { check_lobby }
        @lobby_task.add_observer(ErrorHandler.new)

        @ids_to_check = Concurrent::Array.new
        @connections = Concurrent::Map.new
        @heartbeat = Concurrent::TimerTask.execute(execution_interval: 2.5) { check_connections }
        @heartbeat.add_observer(ErrorHandler.new)
      end

      def stop
        @lobby_task.shutdown
        @heartbeat.shutdown
      end

      def find(id)
        @connections[id]
      end

      def on_connect(socket)
        @lobby << Client.new(socket)
      end

      def on_initialize(client)
        @ids_to_check << client.public_id

        @lobby.delete(client)
        @connections[client.public_id] = client
      end

      def on_disconnect(client)
        @ids_to_check.delete(client.public_id)

        @lobby.delete(client)
        @connections.delete(client.public_id)
      end

      private

      # Traverse the array without holding onto its mutex
      def check_lobby
        client = @lobby.shift
        return if client.nil?

        timed_out = (Time.current - client.connected_at) >= @lobby_timeout

        # Hasn't timed out yet, add it back to the top of the array
        return @lobby << client unless timed_out

        client.close
      end

      # Traverse the connections and ping them every so often to determine if they are
      # still connected or not by sending them a heartbeat request
      def check_connections
        id = @ids_to_check.shift
        return if id.nil?

        client = find(id)
        return if client.nil?

        response = client.write(type: :heartbeat).wait_for_response(@heartbeat_timeout)
        return @ids_to_check << id if response.fulfilled?

        client.close
      end
    end
  end
end
