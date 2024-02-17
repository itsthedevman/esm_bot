# frozen_string_literal: true

module ESM
  module Connection
    class Client
      attr_reader :id, :model

      delegate :remote_address, to: :@socket
      delegate :server_id, to: :@model, allow_nil: true

      def initialize(tcp_client, ledger)
        @socket = Socket.new(tcp_client)
        @ledger = ledger

        @id = nil
        @model = nil
        @encryption = nil
        @last_ping_received = nil

        check_every = ESM.config.loops.connection_client.check_every
        @task = Concurrent::TimerTask.execute(execution_interval: check_every) { on_message }
        @thread_pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: 5,
          max_threads: 20,
          max_queue: 250
        )
      end

      def close
        info!(ip: remote_address, state: :closing, public_id: @id, server_id: @model.server_id)

        # TODO: Maybe post a message?
        # TODO: Tell the server to forget our asses
        @socket.close
      end

      def send_message(message, type: :message)
        send_request(type: type, content: @encryption.encrypt(message))
      end

      def on_message
        response = receive_request
        return if response.nil?

        @thread_pool.post do
          case response.type
          when :identification
            on_identification(response)
          when :handshake
            forward_response_to_caller(response)
          else
            raise "Invalid data received: #{response}"
          end
        rescue ESM::Connection::Client::Error => e
          send_request(type: :error, content: e.message)
          close
        rescue => e
          error!(error: e)
          close
        end
      end

      # TODO: This instance will need to disconnect itself if it doesn't receive the identify request within 10 seconds
      def on_identification(response)
        public_id = response.content
        info!(ip: remote_address, state: :unidentified, public_id: public_id)

        model = ESM::Server.find_by_public_id(public_id)
        raise NotAuthorized if model.nil?

        @model = model
        @id = model.public_id
        @encryption = Encryption.new(model.token[:secret])

        info!(ip: remote_address, state: :identified, public_id: @id, server_id: @model.server_id)

        perform_handshake!
        request_initialization!
      end

      # def on_connect
      #   info!(server_uuid: server_uuid, incoming_message: message.to_h)

      #   server = ESM::Server.find_by(uuid: server_uuid)
      #   return error!(error: "Server does not exist", uuid: server_uuid) if server.nil?
      #   return server.community.log_event(:error, message.errors.join("\n")) if message.errors?

      #   ESM::Event::ServerInitialization.new(server, message).run!
      # end

      # def on_message
      #   # Retrieve the original message. If it's nil, the message originated from the client
      #   outgoing_message = @message_overseer.retrieve(incoming_message.id)

      #   info!(
      #     outgoing_message: outgoing_message&.to_h,
      #     incoming_message: incoming_message.to_h
      #   )

      #   # Handle any errors
      #   if incoming_message.errors?
      #     outgoing_message&.on_error(incoming_message)
      #     return
      #   end

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
      # end

      # def on_disconnect
      #   server_uuid = request[:content]

      #   server = ESM::Server.find_by(uuid: server_uuid)
      #   server.metadata.clear!

      #   info!(uuid: server.public_id, name: server.server_name, server_id: server.server_id)
      # end

      private

      def receive_request
        data = ESM::JSON.parse(@socket.read)
        return if data.blank?

        debug!(read: data)
        Response.new(**data)
      end

      def send_request(type:, content: nil)
        request = Request.new(type: type, content: content)

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
          Result.rejected(TimeoutError.new)
        end
      ensure
        @ledger.remove(request) if request
      end

      def forward_response_to_caller(response)
        mailbox = @ledger.remove(response)
        raise InvalidMessage if mailbox.nil?

        mailbox.put(response)
      end

      def perform_handshake!
        info!(ip: remote_address, state: :handshake, public_id: @id, server_id: @model.server_id)

        starting_indices = @encryption.nonce_indices
        @encryption.regenerate_nonce_indices

        debug!(starting_indices: starting_indices, new_indices: @encryption.nonce_indices)

        message = ESM::Message.event.set_data(:handshake, indices: @encryption.nonce_indices)
        response = send_request(
          type: :handshake,
          content: @encryption.encrypt(message.to_s, nonce_indices: starting_indices)
        )

        binding.pry
      end

      def request_initialization!
      end
    end
  end
end
