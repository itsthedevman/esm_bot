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
        info!("#{tcp_client.local_address.inspect} connecting")

        @tcp_server = tcp_server
        @socket = Socket.new(tcp_client)
        @ledger = Ledger.new
        @config = ESM.config.connection_client

        @id = nil
        @model = nil
        @metadata = set_metadata(vg_enabled: false, vg_max_sizes: 0)
        @connected = Concurrent::AtomicBoolean.new

        @tasks = [
          Concurrent::TimerTask.execute(execution_interval: @config.request_check) { read }
        ]
      end

      def connected?
        @connected.true?
      end

      def set_metadata(**)
        @metadata = Metadata.new(**)
      end

      def close(reason = nil)
        return unless connected?

        info!(
          address: local_address.inspect,
          public_id: @id,
          server_id: @model&.server_id,
          state: :disconnected,
          reason:
        )

        @tasks.each(&:shutdown)
        @connected.make_false

        @tcp_server.client_disconnected(self)

        @socket.close
      end

      def send_message(message, **)
        send_request(message, type: :message, **)
      end

      def send_error(error, **)
        send_request(error, type: :error, **)
      end

      def send_request(content = nil, type:, block: true)
        raise NotConnected, @model&.server_id unless connected?

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
      # @see #send_request or #send_message for higher level methods
      #
      # @param id [String, nil] A UUID, if any, that will be used to differentiate this request
      # @param type [Symbol] The request type. See ESM::Connection::Client::Request::TYPES for full list
      # @param content [Symbol, Array<Numeric>, nil, #bytes] The content to send in the request
      # @param block [true, false] Should this method block and wait for the response?
      #
      # @return [ESM::Connection::Client::Promise]
      #
      def write(type:, id: nil, content: nil)
        raise NotConnected, @model&.server_id unless connected?

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
    end
  end
end
