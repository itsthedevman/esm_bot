# frozen_string_literal: true

module ESM
  module Connection
    class Server
      def initialize
        @ledger = Ledger.new
        @status = Inquirer.new(:stopped, :paused, :started, default: :stopped)
        @connections = Concurrent::Map.new
        @waiting_room = WaitingRoom.new
        @config = ESM.config.connection_server
      end

      def start
        @server = Socket.new(
          TCPServer.new("0.0.0.0", ESM.config.ports.connection_server)
        )

        @connect_task = Concurrent::TimerTask.execute(execution_interval: @config.connection) do
          on_connect
        end

        @disconnect_task = Concurrent::TimerTask.execute(execution_interval: @config.waiting_room) do
          check_waiting_room
        end

        resume
        info!(status: @status)
      end

      def pause
        @status.set(:paused)
      end

      def resume
        @status.set(:started)
      end

      def stop
        @status.set(:stopped)
        @connections.each(&:close)

        @waiting_room.shutdown
        @connect_task.shutdown
        @disconnect_task.shutdown

        @server&.shutdown(:RDWR) if @server&.readable?(0) || @server&.writeable?(0)
      end

      def connected(client)
        @waiting_room.delete(client)
        @connections[client.id] = client
      end

      def disconnected(client)
        @waiting_room.delete(client)
        @connections.delete(client.id) if client.id
      end

      private

      def on_connect
        return unless @status.started?

        client = Client.new(self, @server.accept, @ledger)
        @waiting_room << client
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
