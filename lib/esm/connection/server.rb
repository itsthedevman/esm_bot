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

      def self.connections
        return if @instance.nil?

        @instance.connections
      end

      ################################
      # Instance methods
      ################################

      attr_reader :server, :connections

      def initialize
        # Cache the server_keys in memory. Querying by ID is way faster
        self.refresh_keys

        # The manager handles keeping connections alive and burying them if they're dead.
        @connections = ESM::Connection::Manager.new

        # Everything below is all setup and communication with the rust extension
        Rutie.new(:tcp_server, lib_path: "crates/tcp_server/target/release").init('esm_tcp_server', ESM.root)
        @server = ::ESM::TCPServer.new(self)
        @server.listen(ENV["CONNECTION_SERVER_PORT"])
        @thread = Thread.new { @server.process_requests }
      end

      def stop_server
        return if @server.nil?

        @server.stop
      end

      def disconnect(resource_id)
        connection = @connections.remove(resource_id)
        @server.disconnect(resource_id)
        return if connection.nil?

        connection.run_callback("on_close")
      end

      def send_message(server_id, message)
        # Get resource_id via server_id
        # Send message to extension
        # @server.send_message(adapter_id, message) #-> Can raise ESM::Exception::ServerNotConnected
      end

      def refresh_keys
        @server_keys = ESM::Server.all.pluck(:server_key, :id).to_h
      end

      # Authenticates the message.
      # @raises ESM::Exception::FailedAuthentication
      def authenticate!(connection, key)
        raise ESM::Exception::FailedAuthentication, "Missing authorization key" if key.blank?

        server = ESM::Server.where(id: @server_keys[key]).first
        raise ESM::Exception::FailedAuthentication, "Invalid Key" if server.nil?

        # If the bot is no longer a member of the server, don't allow it to connect
        discord_server = server.community.discord_server
        raise ESM::Exception::FailedAuthentication, "Unable to find Discord Server" if discord_server.nil?

        connection.server = server
        connection.run_callback("on_open") if !connection.authenticated?
      end

      # @note Called from the TCPServer
      # @note Blocks execution on the TCPServer
      def on_connect(resource_id)
        Thread.new do
          # Track this connection. Drop it if it never authenticates.
          connection = ESM::Connection.new(self, resource_id)
          @connections.add_unauthenticated(resource_id, connection)

          ESM::Notifications.trigger("info", class: self.class, method: __method__, resource_id: resource_id)
        rescue StandardError => e
          ESM::Notifications.trigger("error", class: self.class, method: __method__, resource_id: resource_id, error: e)
        end
      end

      # @note Called from the TCPServer
      # @note Blocks execution on the TCPServer
      def on_message(resource_id, client_message)
        Thread.new do
          client_message = client_message.to_ostruct
          connection = @connections.find_by_resource_id(resource_id)

          # Every message must contain the server key
          authenticate!(connection, client_message.key)

          connection.run_callback("on_message", client_message)
        rescue ESM::Exception::FailedAuthentication => _e
          self.disconnect(resource_id)
        rescue StandardError => e
          ESM::Notifications.trigger("error", class: self.class, method: __method__, resource_id: resource_id, error: e)
        end
      end

      # @note Called from the TCPServer
      # @note Blocks execution on the TCPServer
      def on_disconnect(resource_id)
        Thread.new do
          connection = @connections.remove(resource_id)
          next if connection.nil?

          connection.run_callback("on_close")

          ESM::Notifications.trigger("info", class: self.class, method: __method__, resource_id: resource_id)
        rescue StandardError => e
          ESM::Notifications.trigger("error", class: self.class, method: __method__, resource_id: resource_id, error: e)
        end
      end
    end
  end
end
