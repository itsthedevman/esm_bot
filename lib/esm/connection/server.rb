# frozen_string_literal: true

module ESM
  class Connection
    class Server
      ################################
      # Class methods
      ################################

      def self.run!
        @instance = self.new
      end

      def self.stop!
        return if @instance.nil?

        @instance.stop_server
      end

      ################################
      # Instance methods
      ################################

      attr_reader :server

      def initialize
        @connections = ESM::Connection::Manager.new
        Rutie.new(:tcp_server, lib_path: "crates/tcp_server/target/release").init('esm_tcp_server', ESM.root)

        # These are calls to crates/tcp_server
        @server = ::ESM::TCPServer.new(self)
        @server.listen(ENV["CONNECTION_SERVER_PORT"])
        @server.process_requests
      end

      def send_message(server_id, message)
        # Get resource_id via server_id
        # Send message to extension
        # @server.send_message(adapter_id, message) #-> Can raise ESM::Exception::ServerNotConnected
      end

      def stop_server
        return if @server.nil?

        @server.stop
      end

      def close(resource_id)
        connection = @connections.find_by_resource_id(resource_id)
        connection.close
      end

      def on_connected(resource_id)
        # Track this connection. Drop it if it never authenticates.
        connection = ESM::Connection.new(self, resource_id)
        @connections.add_unauthenticated(connection)

        ESM::Notifications.trigger("info", class: self.class, method: __method__, resource_id: resource_id)
      end
    end
  end
end
