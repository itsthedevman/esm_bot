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
        @server_alive = false
        @server_pong_received = true

        # Redis connection for sending messages and reloading keys
        @redis = Redis.new(REDIS_OPTS)

        self.refresh_keys
        self.ping_server
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
          @thread_ping_server
        ].each { |id| Thread.kill(id) }

        # TODO: Close any open requests with an error message

        # Tell the tcp server that we're closing
        self.send_message(type: "close")

        # Close the connection to redis
        @redis.close
        @redis_process_inbound_messages.close
        @redis_delegate_inbound_messages.close
      end

      def send_message(**args)
        # Raise exception if @server_alive false and args[:ignore_alive] false
        if args[:server_id]
          args.merge(
            resource_id: @server_id_by_resource_id.key(args[:server_id])
          )
        end

        raise ESM::Exception::ServerNotConnected if !@server_alive

        send_to_server(**args)
      end

      private

      # Using the provided arguments, build and send a message to the server
      def send_to_server(**args)
        message = ESM::Connection::Message.new(**args)

        if %w[ping pong].exclude?(message.type) # rubocop:disable Style/IfUnlessModifier
          ESM::Notifications.trigger("info", class: self.class, method: __method__, message: message.to_h)
        end

        @redis.rpush("connection_server_outbound", message.to_s)
      end

      # Store all of the server_ids and their keys in redis.
      # This will allow the TCPServer to quickly pull a key by a server_id to decrypt messages
      def refresh_keys
        server_keys = ESM::Server.all.pluck(:server_id, :server_key)

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
              Thread.new { process_inbound_message(message.to_ostruct) }
            end
          end
      end

      # TODO: Documentation
      #
      def ping_server
        @thread_ping_server =
          Thread.new do
            loop do
              sleep(0.5)
              next if !@server_pong_received

              @server_pong_received = false
              self.send_to_server(type: "ping")

              # Wait 200ms for the server to reply before considering it offline
              currently_alive = false
              0..200.times do
                break currently_alive = true if @server_pong_received

                sleep(0.001)
              end

              # Only set the value if it differs
              next if @server_alive == currently_alive

              @server_alive = currently_alive

              if currently_alive
                ESM::Notifications.trigger("info", class: self.class, method: __method__, server_status: "Connected")
              else
                ESM::Notifications.trigger("error", class: self.class, method: __method__, server_status: "Disconnected")
              end
            end
          end
      end

      # TODO: Documentation
      #
      def process_inbound_message(message)
        case message.type
        when "connect"
          self.on_connect(message)
        when "disconnect"
          self.on_disconnect(message)
        when "ping"
          self.on_ping(message)
        when "pong"
          self.on_pong(message)
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
        resource_id = message.resource_id

        connection = ESM::Connection.new(self, server_id, resource_id)
        connection.run_callback(:on_open)

        @connections[server_id] = connection
        @server_id_by_resource_id[resource_id] = message.server_id

        ESM::Notifications.trigger("info", class: self.class, method: __method__, server_id: message.server_id)
      end

      # TODO: Documentation
      #
      def on_message(message)
        ESM::Notifications.trigger("info", class: self.class, method: __method__, message: message.to_h)

        connection = @connections[message.server_id]
        connection.run_callback(:on_message, message)
      end

      # TODO: Documentation
      #
      def on_disconnect(message)
        server_id = @server_id_by_resource_id.delete(message.resource_id)
        connection = @connections.delete(server_id)

        ESM::Notifications.trigger("info", class: self.class, method: __method__, server_id: server_id)
        return if connection.nil?

        connection.run_callback(:on_close)
      end

      # TODO: Documentation
      #
      def on_ping(_message)
        self.send_message(type: "pong")
      end

      # TODO: Documentation
      #
      def on_pong(_message)
        @server_pong_received = true
      end
    end
  end
end
