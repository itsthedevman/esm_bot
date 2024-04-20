# frozen_string_literal: true

module ESM
  module Connection
    class Client
      include Lifecycle

      Metadata = ImmutableStruct.define(:vg_enabled, :vg_max_sizes)

      attr_reader :id, :model

      delegate :address, to: :@socket
      delegate :server_id, to: :@model, allow_nil: true

      def initialize(tcp_client)
        @socket = ClientSocket.new(tcp_client)
        @ledger = Ledger.new
        @config = ESM.config.connection_client

        @id = nil
        @model = nil
        @metadata = set_metadata(vg_enabled: false, vg_max_sizes: 0)
        @thread_pool = Concurrent::CachedThreadPool.new

        execution_interval = @config.request_check
        @task = Concurrent::TimerTask.execute(execution_interval:) { on_message }
        @task.add_observer(ErrorHandler.new)

        @connected_at = Time.current
        info!(address:, state: :on_connect)
      end

      def set_metadata(**)
        @metadata = Metadata.new(**)
      end

      def close(reason)
        ESM.connection_server.on_disconnect(self)

        warn!(
          address:,
          public_id: @id,
          server_id: @model&.server_id,
          state: :disconnected,
          reason:
        )

        @task.shutdown
        @socket.close
      end

      def send_message(message, **)
        send_request(message, type: :message, **)
      end

      def send_error(error, block: false)
        send_request(error, type: :error, block:)
      end

      def send_request(content = nil, type:, block: true)
        info!(
          address:,
          public_id: @id,
          server_id: @model&.server_id,
          outbound: {type:, content: content.respond_to?(:to_h) ? content.to_h : content}
        )

        promise = write(
          id: (content.respond_to?(:id) ? content.id : nil),
          type:,
          content: content.to_s
        )

        return promise.execute unless block

        response = promise.wait_for_response(@config.response_timeout)
        raise RejectedRequest, response.reason if response.rejected?

        message = ESM::Message.from_string(response.value)
        message.metadata.server_id = @model.server_id

        info!(
          address:,
          public_id: @id,
          server_id: @model.server_id,
          inbound: message.to_h
        )

        raise ExtensionError, message.error_messages.join("\n") if message.errors?

        message
      end

      #
      # Lower level method to send a request to the client and either disregard the response or block (default)
      #
      # @see #send_request or #send_message for higher level methods
      #
      # @param id [String, nil] A UUID, if any, that will be used to differentiate this request
      # @param type [Symbol] The request type.
      #     See ESM::Connection::Client::Request::TYPES for full list
      # @param content [Symbol, Array<Numeric>, nil, #bytes] The content to send in the request
      # @param block [true, false] Should this method block and wait for the response?
      #
      # @return [ESM::Connection::Client::Promise]
      #
      def write(type:, id: nil, content: nil)
        request = Request.new(id: id, type: type, content: content)

        # Adding the request to the ledger allows us to track the request across multiple threads
        # ensuring the response to passed back to the blocking thread
        promise = @ledger.add(request)

        # All data passed is in JSON format
        # ESM will never be huge to the point where JSON is a limitation so this
        # isn't a concern of mine
        content = request.to_json

        # Errors can happen before we properly set up encryption.
        # Bypassing encryption means we can better communicate
        content = @encryption.encrypt(content) if type != :error

        # As I've learned there are reasons why Base64 is important for networking
        # I can guess that Unicode is one of them because I've experienced some
        # weird behavior without this
        content = Base64.strict_encode64(content)

        # Once the promise is executed, write the content to the client
        promise.then { @socket.write(content) }
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

      def on_message
        request = read
        return if request.nil?

        @thread_pool.post { process_message(request) }
      end
    end
  end
end
