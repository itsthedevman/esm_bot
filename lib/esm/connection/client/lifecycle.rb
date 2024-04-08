# frozen_string_literal: true

module ESM
  module Connection
    class Client
      module Lifecycle
        private

        def forward_response_to_caller(response)
          promise = @ledger.remove(response)
          raise InvalidMessage if promise.nil?

          promise.set_response(response)
        end

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
            send_error(e.message)
            close(e.message)
          rescue => e
            error!(error: e)
            close("An error occurred")
          ensure
            @ledger.remove(request)
          end
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
        rescue Error => e
          close(e.message)
        end

        def perform_handshake!
          new_indices = @encryption.generate_nonce_indices
          message = ESM::Message.new.set_data(:handshake, indices: new_indices)

          info!(address: local_address.inspect, public_id: @id, server_id: @model.server_id, state: :handshake)

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

          ESM::Event::ServerInitialization.new(self, message).run!
        end

        def on_request(request)
          message = ESM::Message.from_string(request.content)

          info!(
            address: local_address.inspect,
            public_id: @id,
            server_id: @model.server_id,
            inbound: message.to_h
          )

          # Handle any errors
          if message.errors?
            error!(errors: message.error_messages.join("\n"))
            return
          end

          @model.reload

          @thread_pool.post do
            case message.data_type
            when :send_to_channel
              ESM::Event::SendToChannel.new(@model, message).run!
            else
              raise "Invalid data received: #{message}"
            end
          end
        rescue => e
          error!(error: e)
        end
      end
    end
  end
end
