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

      def initialize(tcp_server, tcp_client, ledger)
        @tcp_server = tcp_server
        @socket = Socket.new(tcp_client)
        @ledger = ledger
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

      def close
        @socket.close

        info!(address: local_address.inspect, public_id: @id, server_id: @model&.server_id, state: :disconnected)

        @task.shutdown
      ensure
        @tcp_server.disconnected(self)
      end

      def send_message(message = nil, type: :message, wait_for_response: true, nonce_indices: [])
        info!(
          address: local_address.inspect,
          public_id: @id,
          server_id: @model.server_id,
          outbound: {type: type, message: message.to_h}
        )

        response = send_request(
          id: message ? message.id : nil,
          type: type,
          content: @encryption.encrypt(message.to_s, nonce_indices: nonce_indices),
          wait_for_response: wait_for_response
        )

        return unless wait_for_response
        raise RejectedMessage, response.reason if response.rejected?

        decrypted_message = @encryption.decrypt(response.value)
        ESM::Message.from_string(decrypted_message)
      end

      def set_metadata(**)
        @metadata = Metadata.new(**)
      end

      private

      def receive_request
        data = ESM::JSON.parse(@socket.read)
        return if data.blank?

        Response.new(**data)
      end

      def send_request(type:, content: nil, id: nil, wait_for_response: true)
        request = Request.new(id: id, type: type, content: content)

        # This tracks the request and allows us to receive the response across multiple threads
        mailbox = @ledger.add(request) if wait_for_response

        # Send the data to the client
        @socket.write(request.to_json)

        return unless wait_for_response

        # And here is where we receive it
        case (result = mailbox.take(@config.response_timeout))
        when Response
          Result.fulfilled(result.content)
        when StandardError
          Result.rejected(result)
        else
          # Concurrent::MVar::TIMEOUT
          Result.rejected(RequestTimeout.new)
        end
      end

      def forward_response_to_caller(response)
        mailbox = @ledger.remove(response)
        raise InvalidMessage if mailbox.nil?

        mailbox.put(response)
      end
    end
  end
end
