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

      ################################
      # Instance methods
      ################################

      attr_reader :server, :connections

      def initialize
        # Cache the server_keys in memory. Querying by ID is way faster
        self.refresh_keys

        # The manager handles keeping connections alive and burying them if they're dead.
        @connections = ESM::Connection::Manager.new

        # An array that holds messages (represented as Hashes) that ESM::TCPServer sends.
        # It looks like this:
        # {
        #   type: Symbol,
        #   resource_id: Symbol,
        #   data: Hash,
        # }
        @inbound_messages = []

        # TODO: Documentation
        #
        @outbound_messages = []

        # Everything below is all setup and communication with the rust extension
        Rutie.new(:tcp_server, lib_path: "crates/tcp_server/target/release").init('esm_tcp_server', ESM.root)

        # Rust: rb_listen(port: RString, inbound_messages: Array, outbound_messages: Array)
        # The outbound and inbound message variables are swapped because what is considered outbound for this class is considered
        # inbound for ESM::TCPServer
        # ESM::TCPServer will hold a reference to these arrays and read/write data to them accordingly.
        ESM::TCPServer.listen(ENV["CONNECTION_SERVER_PORT"], @outbound_messages, @inbound_messages)
        ESM::TCPServer.process_requests

        @thread = self.process_inbound_messages
      end

      # TODO: Documentation
      #
      def stop
        return if ESM::TCPServer.nil?

        ESM::TCPServer.stop
      end

      # TODO: Documentation
      #
      def disconnect(resource_id)
        result = ESM::TCPServer.disconnect(resource_id)
        ESM.logger.debug("#{self.class}##{__method__}") { "Disconnect result: #{result}" }

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

      # TODO: Documentation
      #
      def refresh_keys
        @server_keys = ESM::Server.all.pluck(:server_key, :id).to_h
      end

      private

      # TODO: Documentation
      #
      def process_inbound_messages
        Thread.new do
          loop do
            messages = @inbound_messages.shift(10)
            messages.each { |message| process_message(message) } if messages.size.positive?

            sleep(1)
          end
        end
      end

      # TODO: Documentation
      #
      def process_message(message)
        Thread.new do
          ESM::Notifications.trigger("info", class: self.class, method: __method__, message: message)

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
        raise ESM::Exception::FailedAuthentication, "Missing authorization key" if key.blank?

        server = ESM::Server.where(id: @server_keys[key]).first
        raise ESM::Exception::FailedAuthentication, "Invalid Key" if server.nil?

        # If the bot is no longer a member of the server, don't allow it to connect
        discord_server = server.community.discord_server
        raise ESM::Exception::FailedAuthentication, "Unable to find Discord Server" if discord_server.nil?

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
