# frozen_string_literal: true

module ESM
  module Connection
    class Client
      Metadata = ImmutableStruct.define(:vg_enabled, :vg_max_sizes)

      attr_reader :id, :model
      attr_accessor :initialized

      delegate :local_address, to: :@socket
      delegate :server_id, to: :@model, allow_nil: true

      def initialize(tcp_server, tcp_client, ledger)
        @tcp_server = tcp_server
        @socket = Socket.new(tcp_client)
        @ledger = ledger

        @id = nil
        @model = nil
        @encryption = nil
        @last_ping_received = nil
        @initialized = false
        @metadata = set_metadata(vg_enabled: false, vg_max_sizes: 0)

        check_every = ESM.config.loops.connection_client.check_every
        @task = Concurrent::TimerTask.execute(execution_interval: check_every) { on_message }
        @thread_pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: 2,
          max_threads: 20,
          max_queue: 250
        )
      end

      def close
        return if @id.nil?

        info!(address: local_address.inspect, public_id: @id, server_id: @model&.server_id, state: :disconnected)

        @tcp_server.disconnect(@id)
        @socket.close
      end

      def send_message(message = nil, type: :message, **)
        info!(
          address: local_address.inspect,
          public_id: @id,
          server_id: @model.server_id,
          outbound: {type: type, message: message.to_h}
        )

        response = send_request(
          id: message ? message.id : nil,
          type: type,
          content: @encryption.encrypt(message.to_s, **)
        )

        raise RejectedMessage, response.reason if response.rejected?

        decrypted_message = @encryption.decrypt(response.value)
        ESM::Message.from_string(decrypted_message)
      end

      def set_metadata(**)
        @metadata = Metadata.new(**)
      end

      def on_message
        request = receive_request
        return if request.nil?

        @thread_pool.post do
          case request.type
          when :identification
            on_identification(request)
          when :handshake
            forward_response_to_caller(request)
          when :message
            if @ledger.exists?(request)
              forward_response_to_caller(request)
            else
              on_request(request)
            end
          else
            raise "Invalid data received: #{response}"
          end
        rescue Client::Error => e
          send_request(type: :error, content: e.message)
          close
        rescue => e
          error!(error: e)
          close
        ensure
          @ledger.remove(request)
        end
      end

      # TODO: This instance will need to disconnect itself if it doesn't receive the identify request within 10 seconds
      def on_identification(response)
        public_id = response.content
        info!(address: local_address.inspect, public_id: public_id, server_id: nil, state: :unidentified)

        model = ESM::Server.find_by_public_id(public_id)
        raise InvalidAccessKey if model.nil?

        @model = model
        @id = model.public_id
        @encryption = Encryption.new(model.token[:secret])

        info!(address: local_address.inspect, public_id: @id, server_id: @model.server_id, state: :identified)

        perform_handshake!
        request_initialization!
      rescue Client::RejectedMessage
        close
      end

      def on_request(request)
        decrypted_message = @encryption.decrypt(request.content.bytes)
        message = ESM::Message.from_string(decrypted_message)

        binding.pry
        #   # Handle any errors
        #   if message.errors?
        #     outgoing_message&.on_error(incoming_message)
        #     return
        #   end

        #   # Retrieve the original message. If it's nil, the message originated from the client
        #   outgoing_message = @message_overseer.retrieve(incoming_message.id)

        #   info!(
        #     outgoing_message: outgoing_message&.to_h,
        #     incoming_message: incoming_message.to_h
        #   )

        #   # Currently, :send_to_channel is the only inbound event. If adding another, convert this code
        #   if incoming_message.type == :event && incoming_message.data_type == :send_to_channel
        #     server = ESM::Server.find_by(uuid: server_uuid)
        #     ESM::Event::SendToChannel.new(server, incoming_message).run!
        #     return
        #   end

        #   outgoing_message&.on_response(incoming_message)
        # rescue => e
        #   command = outgoing_message&.command

        #   # Bubble up to #on_inbound
        #   raise e if command.nil?

        #   raise "Replace!! command.handle_error(e)"
      end

      private

      def receive_request
        data = ESM::JSON.parse(@socket.read)
        return if data.blank?

        Response.new(**data)
      end

      def send_request(type:, content: nil, id: nil)
        request = Request.new(id: id, type: type, content: content)

        # This tracks the request and allows us to receive the response across multiple threads
        mailbox = @ledger.add(request)

        # Send the data to the client
        @socket.write(request.to_json)

        # And here is where we receive it
        case (result = mailbox.take(10))
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

      def perform_handshake!
        info!(address: local_address.inspect, public_id: @id, server_id: @model.server_id, state: :handshake)

        starting_indices = @encryption.nonce_indices
        @encryption.regenerate_nonce_indices

        message = ESM::Message.event.set_data(:handshake, indices: @encryption.nonce_indices)

        # The response is not needed here
        # However, the message must be responded to in order to confirm the handshake was a success
        send_message(message, type: :handshake, nonce_indices: starting_indices)
      end

      def request_initialization!
        info!(address: local_address.inspect, public_id: @id, server_id: @model.server_id, state: :initialization)

        message = send_message(type: :initialize)
        ESM::Event::ServerInitialization.new(self, message).run!
      end
    end
  end
end
