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

        @instance.stop
      end

      def self.connections
        return if @instance.nil?

        @instance.connections
      end

      def self.find_by_resource_id(resource_id)
        @instance.find_by_resource_id(resource_id)
      end

      def self.find_by_server_id(server_id)
        @instance.find_by_server_id(server_id)
      end

      ################################
      # Instance methods
      ################################

      attr_reader :server, :connections

      def initialize
        # The manager handles keeping connections alive and burying them if they're dead.
        @connections = ESM::Connection::Manager.new

        # A channel that facilitates communication with ESM::TCPServer.
        # ESM::TCPServer will add hashes to this array for this class to process. See #process_inbound_messages for more details
        @inbound_messages = []

        # A channel that facilitates communication with ESM::TCPServer.
        # Hashes added to this array will be processed by ESM::TCPServer. See #send_message for more details
        @outbound_messages = []

        # Everything below is all setup and communication with the rust extension
        Rutie.new(:tcp_server, lib_path: "crates/tcp_server/target/release").init('esm_tcp_server', ESM.root)

        # Rust: rb_listen(port: RString, inbound_messages: Array, outbound_messages: Array)
        # The outbound and inbound message variables are swapped because what is considered outbound for this class is considered
        # inbound for ESM::TCPServer
        ESM::TCPServer.listen(ENV["CONNECTION_SERVER_PORT"], @outbound_messages, @inbound_messages)
        ESM::TCPServer.process_requests

        self.refresh_keys
        self.process_inbound_messages
      end

      delegate :find_by_resource_id, :find_by_server_id, to: :@connections

      # TODO: Documentation
      #
      def stop
        return if ESM::TCPServer.nil?

        ESM::TCPServer.stop
        Thread.kill(@thread) if !@thread.nil?
      end

      # TODO: Documentation
      #
      def disconnect(resource_id)
        disconnected = ESM::TCPServer.disconnect(resource_id)
        return if !disconnected

        connection = @connections.remove(resource_id)
        return if connection.nil?

        connection.run_callback("on_close")
      end

      # TODO: Documentation
      #
      # @raises ESM::Exception::ClientNotConnected
      # @raises ESM::Exception::ConnectionNotFound
      def send_message(resource_id, type:, data:, metadata: {})
        connection = @connections.find_by_resource_id(resource_id)
        raise ESM::Exception::ConnectionNotFound, resource_id if connection.nil?

        # Send message to extension, this can raise ESM::Exception::ClientNotConnected
        ESM::TCPServer.send_message(adapter_id, id: id, type: type, data: data, metadata: metadata)
      end

      # Cache the server_keys with the key being the server_key and the value being its ID.
      # Cuts query time in half when authenticating
      #
      def refresh_keys
        @server_keys = ESM::Server.all.pluck(:server_key, :id).to_h
      end

      private

      # TODO: Documentation
      #
      def process_inbound_messages
        @thread =
          Thread.new do
            loop do
              messages = @inbound_messages.shift(10)
              messages.each { |message| process_inbound_message(message) } if messages.size.positive?

              sleep(0.5)
            end
          end
      end

      # TODO: Documentation
      #
      def process_inbound_message(message)
        Thread.new do
          case message[:type]
          when :connection_event
            event = message.dig(:data, :event)
            next if event.nil?

            self.send(event, message.to_ostruct)
          end
        end
      end

      # TODO: Documentation
      #
      # @raises ESM::Exception::FailedAuthentication
      def authenticate!(connection, key)
        raise ESM::Exception::FailedAuthentication, "Missing server key" if key.blank?

        server = ESM::Server.where(id: @server_keys[key]).first
        raise ESM::Exception::FailedAuthentication, "Invalid server key" if server.nil?

        # If the bot is no longer a member of the server, don't allow it to connect
        discord_server = server.community.discord_server
        raise ESM::Exception::FailedAuthentication, "Failed to load associated discord server. Ensure ESM is a member of your Discord Server" if discord_server.nil?

        connection.server = server
        connection.run_callback(:on_open) if !connection.authenticated?
      end

      # TODO: Documentation
      #
      def on_connect(message)
        resource_id = message.resource_id

        # Track this connection. Drop it if it never authenticates.
        connection = ESM::Connection.new(self, resource_id)
        @connections.add_unauthenticated(resource_id, connection)
      rescue StandardError => e
        ESM::Notifications.trigger("error", class: self.class, method: __method__, resource_id: resource_id, error: e)
      end

      # TODO: Documentation
      #
      def on_message(message)
        resource_id = message.resource_id
        connection = @connections.find_by_resource_id(resource_id)

        # Every message must contain the server key
        authenticate!(connection, message.data.key)

        connection.run_callback(:on_message, message.data)
      rescue ESM::Exception::FailedAuthentication => e
        ESM::Notifications.trigger("error", class: self.class, method: __method__, resource_id: resource_id, error: e)
        self.disconnect(resource_id)
      rescue StandardError => e
        ESM::Notifications.trigger("error", class: self.class, method: __method__, resource_id: resource_id, error: e)
      end

      # TODO: Documentation
      #
      def on_disconnect(message)
        resource_id = message.resource_id
        connection = @connections.remove(resource_id)
        return if connection.nil?

        connection.run_callback(:on_close)
      rescue StandardError => e
        ESM::Notifications.trigger("error", class: self.class, method: __method__, resource_id: resource_id, error: e)
      end
    end
  end
end
