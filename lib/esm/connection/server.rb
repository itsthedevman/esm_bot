# frozen_string_literal: true

module ESM
  class Connection
    class Server
      REDIS_OPTS = {
        reconnect_attempts: 10,
        reconnect_delay: 1.5,
        reconnect_delay_max: 10.0
      }.freeze
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

        # Redis connection for sending messages and reloading keys
        @redis_general = Redis.new(REDIS_OPTS)

        self.refresh_keys
        self.delegate_inbound_messages
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
      def send_message(data:, metadata: {}, type: "server_message", resource_id: nil)
        if !resource_id.nil?
          connection = @connections.find_by_resource_id(resource_id)
          raise ESM::Exception::ConnectionNotFound, resource_id if connection.nil?
        end

        message = {
          resource_id: resource_id,
          type: type,
          data: data,
          metadata: metadata
        }.to_json

        ESM.logger.debug("#{self.class}##{__method__}") { "Sending: #{message}" }
        @redis_general.rpush("connection_server_outbound", message)
      end

      # Store all of the server_ids and their keys in redis.
      # This will allow the TCPServer to quickly pull a key by a server_id to decrypt messages
      def refresh_keys
        server_keys = ESM::Server.all.pluck(:server_id, :server_key)

        # @redis_general.hmset("server_keys", *server_keys)
      end

      private

      # TODO: Documentation
      #
      def delegate_inbound_messages
        @redis_delegate_inbound_messages = Redis.new(REDIS_OPTS)

        @thread =
          Thread.new do
            loop do
              # Redis gem does not support BLMOVE as a method :(
              @redis_delegate_inbound_messages.synchronize do |client|
                client.call_with_timeout([:blmove, "tcp_server_outbound", "connection_server_inbound", "LEFT", "RIGHT", 0], 0)
              end
            end
          end
      end

      # TODO: Documentation
      #
      def process_inbound_messages
        @redis_process_inbound_messages = Redis.new(REDIS_OPTS)

        @thread =
          Thread.new do
            loop do
              _name, message = @redis_process_inbound_messages.blpop("connection_server_inbound")
              Thread.new { process_inbound_message(message.to_ostruct) }
            end
          end
      end

      # TODO: Documentation
      #
      def process_inbound_message(message)
        case message.type
        when :connection_event
          event = message.data.event
          return if event.nil?

          self.send(event, message)
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
