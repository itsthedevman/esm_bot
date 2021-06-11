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

        # Redis connection for sending messages and reloading keys
        @redis = Redis.new(REDIS_OPTS)

        self.refresh_keys
        self.delegate_inbound_messages
        self.process_inbound_messages
      end

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

      def send_message(**args)
        if args[:server_id]
          args.merge(
            resource_id: @server_id_by_resource_id.key(args[:server_id])
          )
        end

        message = ESM::Connection::Message.new(**args)

        ESM::Notifications.trigger("info", class: self.class, method: __method__, message: message.to_h)

        @redis.rpush("connection_server_outbound", message.to_s)
      end

      private

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
        ESM::Notifications.trigger("info", class: self.class, method: __method__, message: message.to_h)

        case message.type
        when "on_connect"
          self.on_connect(message)
        when "on_disconnect"
          self.on_disconnect(message)
        else
          self.on_message(message)
        end
      end

      # TODO: Documentation
      #
      def on_connect(message)
        server_id = message.server_id
        connection = ESM::Connection.new(self, server_id)
        connection.run_callback(:on_open)

        @connections[server_id] = connection
        @server_id_by_resource_id[message.resource_id] = message.server_id
      end

      # TODO: Documentation
      #
      def on_message(message)
        connection = @connections[message.server_id]
        connection.run_callback(:on_message, message)
      end

      # TODO: Documentation
      #
      def on_disconnect(message)
        server_id = @server_id_by_resource_id.delete(message.resource_id)
        connection = @connections.delete(server_id)
        return if connection.nil?

        connection.run_callback(:on_close)
      end
    end
  end
end
