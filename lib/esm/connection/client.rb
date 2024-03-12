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
        info!(address: local_address.inspect, public_id: @id, server_id: @model&.server_id, state: :disconnected)

        @task.shutdown
        @socket.close
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
          content: message.to_s,
          type:,
          wait_for_response:,
          nonce_indices:
        )

        return unless wait_for_response
        raise RejectedMessage, response.reason if response.rejected?

        ESM::Message.from_string(response.value)
      end

      def set_metadata(**)
        @metadata = Metadata.new(**)
      end
    end
  end
end
