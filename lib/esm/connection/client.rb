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

        check_every = ESM.config.loops.connection_client.check_every
        @task = Concurrent::TimerTask.execute(execution_interval: check_every) { on_message }
      end

      def close
        # TODO: Maybe post a message?
        @socket.close
      end

      def request_identification!
        response = __send(type: :identify)
        raise response.reason if response.rejected?

        model = ESM::Server.find_by_public_id(response.value)
        raise "TODO: Invalid public_id" if model.nil?

        @id = model.public_id
        @model = model
      end

      def perform_handshake!
      end

      def request_initialization!
      end

      def on_message
        response = __receive
        return if response.nil?

        case response.type
        when :identify
          mailbox = @ledger.remove(response)
          raise InvalidMessage if mailbox.nil?

          # The Lake House, is that you?
          mailbox.put(response)
        else
          raise "Invalid data received: #{response}"
        end
      rescue => e
        binding.pry
        # Send closing message? Or just close?
        @socket.close
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

      def __receive
        data = ESM::JSON.parse(@socket.read)
        return if data.blank?

        Response.new(**data)
      end

      def __send(type:, content: nil)
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
        @ledger.remove(request)
      end
    end
  end
end
