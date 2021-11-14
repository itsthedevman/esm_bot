# frozen_string_literal: true

module ESM
  class Connection
    class Server
      ################################
      # Class methods
      ################################

      class << self
        attr_reader :instance

        delegate :disconnect_all!, :pause, :resume, to: :@instance, allow_nil: true

        def run!
          @instance = self.new
        end

        def stop!
          return true if @instance.nil?

          @instance.stop
          @instance = nil
        end

        def connection(server_id)
          return if @instance.nil?

          @instance.connections[server_id]
        end
      end

      ################################
      # Instance methods
      ################################

      attr_reader :server, :connections, :message_overseer

      def initialize
        @connections = {} # By server_id
        @server_id_by_resource_id = {}
        @mutex = Mutex.new
        @redis = Redis.new(ESM::REDIS_OPTS)
        @message_overseer = ESM::Connection::MessageOverseer.new

        @redis.del("connection_server_outbound")
        @redis.del("connection_server_inbound")

        self.tcp_server_alive = true
        self.server_ping_received = true
        self.refresh_keys
        self.health_check
        self.delegate_inbound_messages
        self.process_inbound_messages

        ESM::Notifications.trigger("info", class: self.class, method: __method__, status: "Started")
      end

      def stop
        # Kill the processing threads
        [
          @thread_delegate_inbound_messages,
          @thread_process_inbound_messages,
          @thread_health_check
        ].each { |id| Thread.kill(id) }

        @message_overseer.remove_all!(with_error: true)
        self.disconnect_all!

        # Close the connection to redis
        @redis.close
        @redis_process_inbound_messages.close
        @redis_delegate_inbound_messages.close

        true
      end

      def resume
        message = ESM::Connection::Message.new(type: :resume)
        __send_internal(message)
      end

      def pause
        message = ESM::Connection::Message.new(type: :pause)
        __send_internal(message)
      end

      def disconnect_all!
        message = ESM::Connection::Message.new(type: :disconnect)
        __send_internal(message)
      end

      def tcp_server_alive?
        @mutex.synchronize { @tcp_server_alive }
      end

      #
      # Sends a message to a client (a3 server)
      #
      # @param message [ESM::Connection::Message] The message to send
      # @param to [String] The ID of the server to send the message to
      # @param forget [Boolean] If false, this message will be registered with the MessageOverseer for automatic timeout. If true, the message is not registered
      # @param wait [Boolean] If true, the request will be considered synchronous and this will block until either the message is responded to or it times out. Option "forget" is ignored when this is true.
      #
      # @return [ESM::Connection::Message] If wait is true, this will be the incoming message containing the response. If wait is false, this is the message that was sent
      #
      def fire(message, to:, forget: false, wait: false)
        raise ESM::Exception::ServerNotConnected if !self.tcp_server_alive?
        raise ESM::Exception::CheckFailureNoMessage if !message.is_a?(ESM::Connection::Message)

        # Watch the message to see if it's been acknowledged or responded to.
        @message_overseer.watch(message) if wait || !forget

        # Wait for a response after the message as sent
        message.synchronous if wait

        # Set some internal data for sending
        if to
          message.server_id = to
          message.resource_id = @server_id_by_resource_id.key(to)
        end

        ESM::Notifications.trigger("info", class: self.class, method: __method__, server_id: to, message: message.to_h.except(:server_id))

        ESM::Test.outbound_server_messages.store(message, to) if ESM.env.test?
        __send_internal(message) unless ESM.env.test? && ESM::Test.block_outbound_messages

        return message.wait_for_response if wait

        message
      end

      def disconnect(server_id, reason: nil)
        ESM::Notifications.trigger("info", class: self.class, method: __method__, server_id: server_id, reason: reason.to_s)

        message = ESM::Connection::Message.new(type: :disconnect)
        message.add_error(type: :message, content: reason) if reason.present?
        fire(message, to: server_id)

        connection = @connections.delete(server_id)
        return if connection.nil?

        connection.on_close
      end

      # Store all of the server_ids and their keys in redis.
      # This will allow the TCPServer to quickly pull a key by a server_id to decrypt messages
      def refresh_keys
        @redis.del("server_keys")

        server_keys = ESM::Server.all.pluck(:server_id, :server_key)
        return if server_keys.blank?

        # Store the data in Redis
        @redis.hmset("server_keys", *server_keys)
      end

      private

      def __send_internal(message)
        @redis.rpush("connection_server_outbound", message.to_s)
      end

      def delegate_inbound_messages
        @redis_delegate_inbound_messages = Redis.new(ESM::REDIS_OPTS)

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

      def process_inbound_messages
        @redis_process_inbound_messages = Redis.new(ESM::REDIS_OPTS)

        @thread_process_inbound_messages =
          Thread.new do
            loop do
              _name, message = @redis_process_inbound_messages.blpop("connection_server_inbound")
              Thread.new { process_inbound_message(message) }
            end
          end
      end

      def health_check
        @thread_health_check =
          Thread.new do
            self.server_ping_received = false

            currently_alive = false
            100.times do
              break currently_alive = true if self.server_ping_received?

              sleep(0.01)
            end

            # Only set the value if it differs
            previously_alive = self.tcp_server_alive?
            next if currently_alive == previously_alive

            self.tcp_server_alive = currently_alive

            if self.tcp_server_alive?
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

      def tcp_server_alive=(value)
        @mutex.synchronize { @tcp_server_alive = value }
      end

      def process_inbound_message(message)
        message = ESM::Connection::Message.from_string(message)

        case message.type
        when "init"
          self.on_connect(message)
        when "disconnect"
          self.on_disconnect(message)
        when "ping"
          self.on_ping(message)
        when "error"
          outgoing_message = @message_overseer.retrieve(message.id)
          outgoing_message.run_callback(:on_error, message, outgoing_message)
        else
          self.on_message(message)
        end
      rescue StandardError => e
        uuid = SecureRandom.uuid
        ESM::Notifications.trigger("error", class: self.class, method: __method__, error: e, id: uuid, message_id: message&.id)

        # Reply back to the message
        message.add_error(type: "message", content: I18n.t("exceptions.system", error_code: uuid))

        self.fire(message, to: message.server_id)
      end

      def on_connect(message)
        server_id = message.server_id

        ESM::Notifications.trigger(
          "info",
          class: self.class,
          method: __method__,
          server_id: { incoming: message.server_id },
          incoming_message: message.to_h.without(:server_id, :resource_id)
        )

        connection = ESM::Connection.new(self, server_id)
        return self.disconnect(server_id) if connection.server.nil?
        return connection.server.community.log_event(:error, message.errors.first.to_s) if message.errors?

        connection.on_open(message)

        @connections[server_id] = connection
        @server_id_by_resource_id[message.resource_id] = message.server_id
      end

      def on_message(incoming_message)
        # Retrieve the original message. If it's nil, the message originated from the client
        outgoing_message = @message_overseer.retrieve(incoming_message.id)

        ESM::Notifications.trigger(
          "info",
          class: self.class,
          method: __method__,
          server_id: { incoming: incoming_message.server_id, outgoing: outgoing_message&.server_id },
          outgoing_message: outgoing_message&.to_h&.without(:server_id, :resource_id),
          incoming_message: incoming_message.to_h.without(:server_id, :resource_id)
        )

        # Skipping ack messages
        ESM::Test.inbound_server_messages.store(incoming_message, incoming_message.server_id) if ESM.env.test? && incoming_message.data.present?

        # Handle any errors
        return outgoing_message.run_callback(:on_error, incoming_message, outgoing_message) if incoming_message.errors?

        # The message is good, call the on_message for this connection
        connection = @connections[incoming_message.server_id]
        return ESM::Notifications.trigger("warn", class: self.class, method: __method__, message: "Connection was nil?") if connection.nil?

        connection.on_message(incoming_message, outgoing_message)
      end

      def on_disconnect(message)
        server_id = @server_id_by_resource_id.delete(message.resource_id)
        connection = @connections.delete(server_id)
        return if connection.nil?

        connection.on_close
      end

      def on_ping(_message)
        self.server_ping_received = true
        @thread_health_check.join

        self.health_check

        message = ESM::Connection::Message.new(type: :pong)
        __send_internal(message)
      end
    end
  end
end
