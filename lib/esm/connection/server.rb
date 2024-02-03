# frozen_string_literal: true

module ESM
  module Connection
    class Server
      ################################
      # Class methods
      ################################

      class << self
        attr_reader :instance

        delegate :disconnect_all!, :pause, :resume, to: :@instance, allow_nil: true

        def run!
          @instance = new
          @instance.start
        end

        def stop!
          return true if @instance.nil?

          @instance.stop
          @instance = nil
        end
      end

      ################################
      # Instance methods
      ################################

      def initialize
        @ledger = Ledger.new
        @connections = Concurrent::Map.new
        @thread_pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: 10,
          max_threads: 50,
          max_queue: 1000
        )
      end

      def start
        @server = TCPServer.new("0.0.0.0", ESM.config.ports.connection_server)

        check_every = ESM.config.loops.connection_server.check_every
        @task = Concurrent::TimerTask.execute(execution_interval: check_every) { on_connect }

        info!(status: "Started")
      end

      def stop
        disconnect_all!
        true
      end

      def resume
        return if @state == :started

        # __send_internal({type: :server_request, content: {type: :resume}})
        binding.pry

        @state = :started
      end

      def pause
        return if @state == :paused

        # __send_internal({type: :server_request, content: {type: :pause}})
        binding.pry

        @state = :paused
      end

      def disconnect_all!
        # __send_internal({type: :server_request, content: {type: :disconnect}})
      end

      #
      # Sends a message to a client (a3 server)
      #
      # @param message [ESM::Message] The message to send
      # @param to [String] The UUID of the server to send the message to
      # @param forget [Boolean] By default (true), the message will be sent asynchronously. Set to false to synchronously send the message. The response message (if any) will be returned from this message
      #
      # @return [ESM::Message] If forget is false, this will be the incoming message containing the response. Otherwise, it will be the outgoing message
      #
      def fire(message, to:, forget: true)
        raise ESM::Exception::CheckFailureNoMessage if !message.is_a?(ESM::Message)

        info!(
          send_opts: {forget: forget},
          server: to,
          message: message.to_h
        )
      end

      private

      def on_connect
        client = Client.new(@server.accept, @ledger)

        @thread_pool.post do
          client.request_identification!
          client.perform_handshake!
          client.request_initialization!

          @connections[client.id] = client
        rescue Client::Error => e
          client.close(e)
        rescue => e
          error!(error: e, remote_address: client.remote_address.getnameinfo, model: client.model)
        end
      end

      def process_inbound_request(json)
        request = json.to_h

        case request[:type]
        when "ping"
          on_ping
        when "disconnected"
          on_disconnect(request)
        when "inbound"
          on_inbound(request)
        end
      end

      def on_inbound(request)
        request = request[:content].to_h

        server_uuid = request[:server_uuid]
        message = ESM::Message.from_hash(request[:message])

        case message.data_type
        when :init
          on_connect(server_uuid, message)
        else
          on_message(server_uuid, message)
        end

        ESM::Test.inbound_server_messages.store(message, server_uuid) if ESM.env.test?
      rescue => e
        uuid = SecureRandom.uuid
        error!(error: e, id: uuid, message_id: message&.id)

        # Prevents getting stuck in a error reporting loop
        if message && !message.errors?
          # Reply back to the message
          message = ESM::Message.event
            .set_id(message.id)
            .add_error("message", I18n.t("exceptions.system", error_code: uuid))

          fire(message, to: server_uuid, forget: true)
        end
      end
    end
  end
end
