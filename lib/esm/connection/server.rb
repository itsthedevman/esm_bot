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

      ################################
      # Instance methods
      ################################

      attr_reader :server, :connections

      def initialize
        @connections = {}
        @server_id_by_resource_id = {}
        @mutex = Mutex.new
        @redis = Redis.new(REDIS_OPTS)
        @message_overseer = ESM::Connection::MessageOverseer.new

        self.server_alive = false
        self.server_ping_received = true
        self.refresh_keys
        self.health_check
        self.delegate_inbound_messages
        self.process_inbound_messages
      end

      # TODO: Documentation
      #
      def stop
        # Kill the processing threads
        [
          @thread_delegate_inbound_messages,
          @thread_process_inbound_messages,
          @thread_health_check
        ].each { |id| Thread.kill(id) }

        # TODO: Close any open requests with an error message

        # Tell the tcp server that we're closing
        self.send_message(type: "close")

        # Close the connection to redis
        @redis.close
        @redis_process_inbound_messages.close
        @redis_delegate_inbound_messages.close
      end

      # Creates and adds a message to the server queue for processing.
      #
      # @param message [Hash, ESM::Connection::Message] This can be either a hash of arguments for ESM::Connection::Message, or an instance of it.
      def send_message(message = {})
        message = ESM::Connection::Message.new(**message) if message.is_a?(Hash)
        message.resource_id = @server_id_by_resource_id.key(message.server_id) if message.server_id

        raise ESM::Exception::ServerNotConnected if !self.server_alive?

        # Watch the message to see if it's been acknowledged or responded to.
        @message_overseer.watch(message)

        send_to_server(message)
      end

      private

      # Using the provided arguments, build and send a message to the server
      def send_to_server(message)
        if %w[pong].exclude?(message.type) # rubocop:disable Style/IfUnlessModifier
          ESM::Notifications.trigger("info", class: self.class, method: __method__, message: message.to_h)
        end

        @redis.rpush("connection_server_outbound", message.to_s)
      end

      # Store all of the server_ids and their keys in redis.
      # This will allow the TCPServer to quickly pull a key by a server_id to decrypt messages
      def refresh_keys
        server_keys = ESM::Server.all.pluck(:server_id, :server_key)
        return if server_keys.blank?

        # Store the data in Redis
        @redis.hmset("server_keys", *server_keys)
      end

      # TODO: Documentation
      #
      def delegate_inbound_messages
        @redis_delegate_inbound_messages = Redis.new(REDIS_OPTS)

        @thread_delegate_inbound_messages =
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

        @thread_process_inbound_messages =
          Thread.new do
            loop do
              _name, message = @redis_process_inbound_messages.blpop("connection_server_inbound")
              Thread.new { process_inbound_message(message) }
            end
          end
      end

      # TODO: Documentation
      #
      def health_check
        @thread_health_check =
          Thread.new do
            self.server_ping_received = false

            currently_alive = false
            0..100.times do
              break currently_alive = true if self.server_ping_received?

              sleep(0.01)
            end

            # Only set the value if it differs
            previously_alive = self.server_alive?
            next if currently_alive == previously_alive

            self.server_alive = currently_alive

            if self.server_alive?
              ESM::Notifications.trigger("info", class: self.class, method: __method__, server_status: "Connected")
            else
              ESM::Notifications.trigger("error", class: self.class, method: __method__, server_status: "Disconnected")
            end
          end
      end

      def server_ping_received?
        @mutex.synchronize { @server_ping_received }
      end

      def server_ping_received=(value)
        @mutex.synchronize { @server_ping_received = value }
      end

      def server_alive?
        @mutex.synchronize { @server_alive }
      end

      def server_alive=(value)
        @mutex.synchronize { @server_alive = value }
      end

      # TODO: Documentation
      #
      def process_inbound_message(message)
        message = ESM::Connection::Message.from_string(message)

        case message.type
        when "init"
          self.on_connect(message)
        when "disconnect"
          self.on_disconnect(message)
        when "ping"
          self.on_ping(message)
        else
          self.on_message(message)
        end
      rescue StandardError => e
        ESM::Notifications.trigger("error", class: self.class, method: __method__, error: e)
      end

      # TODO: Documentation
      #
      def on_connect(message)
        server_id = message.server_id

        connection = ESM::Connection.new(self, server_id)
        connection.on_open(message)

        @connections[server_id] = connection
        @server_id_by_resource_id[message.resource_id] = message.server_id
      end

      # TODO: Documentation
      #
      def on_message(incoming_message)
        # Retrieve the original message
        outgoing_message = @message_overseer.retrieve(incoming_message.id)
        # outgoing_message.nil? #=> This is a client command like discord_log

        connection = @connections[outgoing_message.server_id]
        connection.server.reload # Refresh the server

        ESM::Notifications.trigger(
          "info",
          class: self.class,
          method: __method__,
          server_id: connection.server.server_id,
          outgoing_message: outgoing_message.to_h.without(:server_id, :resource_id),
          incoming_message: incoming_message.to_h.without(:server_id, :resource_id)
        )

        connection.on_message(incoming_message, outgoing_message)
      end

      # TODO: Documentation
      #
      def on_disconnect(message)
        server_id = @server_id_by_resource_id.delete(message.resource_id)
        connection = @connections.delete(server_id)

        ESM::Notifications.trigger("info", class: self.class, method: __method__, server_id: server_id)
        return if connection.nil?

        connection.on_close
      end

      # TODO: Documentation
      #
      def on_ping(_message)
        self.server_ping_received = true
        @thread_health_check.join

        self.health_check

        message = ESM::Connection::Message.new(type: "pong", data_type: "empty")
        self.send_to_server(message)
      end
    end
  end
end
