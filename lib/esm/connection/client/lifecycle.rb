# frozen_string_literal: true

module ESM
  module Connection
    class Client
      module Lifecycle
        private

        def on_message
          request = read
          return if request.nil?

          @thread_pool.post do
            case request.type
            when :identification
              on_identification(request)
            when :handshake
              forward_response_to_caller(request)
            when :message
              if @ledger.include?(request)
                forward_response_to_caller(request)
              else
                on_request(request)
              end
            else
              raise "Invalid data received: #{response}"
            end
          rescue Client::Error => e
            write(type: :error, content: e.message, block: false)
            close
          rescue => e
            error!(error: e)
            close
          ensure
            @ledger.remove(request)
          end
        rescue => e
          error!(error: e)
          close
        end

        def on_identification(response)
          public_id = response.content
          info!(address: local_address.inspect, public_id: public_id, server_id: nil, state: :unidentified)

          model = ESM::Server.find_by_public_id(public_id)
          raise InvalidAccessKey if model.nil?
          raise ExistingConnection if model.connected?

          @model = model
          @id = model.public_id
          @encryption = Encryption.new(model.token[:secret])

          info!(address: local_address.inspect, public_id: @id, server_id: @model.server_id, state: :identified)

          perform_handshake!
          request_initialization!

          @tcp_server.client_connected(self)
        rescue Error
          close
        end

        def on_request(request)
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

        def perform_handshake!
          info!(address: local_address.inspect, public_id: @id, server_id: @model.server_id, state: :handshake)

          new_indices = @encryption.generate_nonce_indices
          message = ESM::Message.event.set_data(:handshake, indices: new_indices)

          # This doesn't use #send_request because it needs to hook into the promise to immediately
          # swap the nonce to the new one before the client has time to respond.
          # Ignorance is bliss but this shouldn't be a race condition due to network lag
          # "It works on my computer"
          response = write(id: message.id, type: :handshake, content: message.to_s)
            .then { |_| @encryption.nonce_indices = new_indices }
            .wait_for_response(@config.response_timeout)

          raise response.reason if response.rejected?

          # Ledger doesn't care what object it is, so long as it responds to #id
          @ledger.remove(message)
        end

        def request_initialization!
          info!(address: local_address.inspect, public_id: @id, server_id: @model.server_id, state: :pre_initialization)

          message = send_request(type: :initialize)

          info!(
            address: local_address.inspect,
            public_id: @id,
            server_id: @model.server_id,
            state: :initialization,
            inbound: message.to_h
          )

          ESM::Event::ServerInitialization.new(self, message).run!
        end
      end
    end
  end
end
