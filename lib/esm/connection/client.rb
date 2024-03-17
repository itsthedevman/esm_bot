# frozen_string_literal: true

module ESM
  module Connection
    class Client
      include Lifecycle

      Metadata = ImmutableStruct.define(:vg_enabled, :vg_max_sizes)

      attr_reader :id, :model
      attr_accessor :initialized

      delegate :local_address, to: :@socket
      delegate :server_id, to: :@model, allow_nil: true

      def initialize(tcp_server, tcp_client)
        @tcp_server = tcp_server
        @socket = Socket.new(tcp_client)
        @ledger = Ledger.new
        @config = ESM.config.connection_client

        @id = nil
        @model = nil
        @encryption = nil
        @last_ping_received = nil
        @initialized = false
        @metadata = set_metadata(vg_enabled: false, vg_max_sizes: 0)

        @task = Concurrent::TimerTask.execute(execution_interval: @config.request_check) { on_message }
        @thread_pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: @config.min_threads,
          max_threads: @config.max_threads,
          max_queue: @config.max_queue
        )
      end

      def set_metadata(**)
        @metadata = Metadata.new(**)
      end

      def close
        info!(address: local_address.inspect, public_id: @id, server_id: @model&.server_id, state: :disconnected)

        @task.shutdown
        @socket.close
      ensure
        @tcp_server.client_disconnected(self)
      end

      def send_request(content = nil, type: :message, block: true)
        info!(
          address: local_address.inspect,
          public_id: @id,
          server_id: @model.server_id,
          outbound: {type: type, content: content.respond_to?(:to_h) ? content.to_h : content}
        )

        promise = write(
          id: (content.respond_to?(:id) ? content.id : nil),
          type:,
          content: content.to_s
        )

        return promise unless block

        response = promise.wait_for_response(@config.response_timeout)
        raise RejectedRequest, response.reason if response.rejected?

        ESM::Message.from_string(response.value)
      end

      #
      # Lower level method to send a request to the client and either disregard the response or block (default)
      #
      # @see #send_request for a higher level method
      #
      # @param id [String, nil] A UUID, if any, that will be used to differentiate this request
      # @param type [Symbol] The request type. See ESM::Connection::Client::Request::TYPES for full list
      # @param content [Symbol, Array<Numeric>, nil, #bytes] The content to send in the request
      # @param block [true, false] Should this method block and wait for the response?
      #
      # @return [ESM::Connection::Client::Promise]
      #
      def write(id: nil, type: :noop, content: nil)
        request = Request.new(id: id, type: type, content: content)

        # This tracks the request and allows us to receive the response across multiple threads
        @ledger.add(request).then do
          # Send the data to the client
          @socket.write(
            Base64.strict_encode64(
              @encryption.encrypt(request.to_json)
            )
          )
        end
      end

      private

      def read
        data = @socket.read
        return if data.blank?

        inbound_data = Base64.strict_decode64(data)

        # The first data we receive should be the identification (when @id is nil)
        # Every request from that point on will be encrypted
        data =
          if @id.nil?
            inbound_data
          else
            @encryption.decrypt(inbound_data)
          end

        data = ESM::JSON.parse(data)
        return if data.blank?

        Request.from_client(data)
      end

      def forward_response_to_caller(response)
        promise = @ledger.remove(response)
        raise InvalidMessage if promise.nil?

        promise.set_response(response)
      end
    end
  end
end
