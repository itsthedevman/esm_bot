# frozen_string_literal: true

module ESM
  module Connection
    class Client
      module Lifecycle
        def on_identification(public_id)
          info!(address:, state: :on_identification, public_id:)

          existing_connection = ESM.connection_server.client(public_id)
          raise ESM::Exception::ExistingConnection if existing_connection

          model = ESM::Server.find_by_public_id(public_id)
          raise ESM::Exception::InvalidAccessKey if model.nil?

          authenticate!(model)
          initialize!(model)
        end

        def on_request(content)
          message = ESM::Message.from_string(content)

          info!(address:, public_id:, server_id:, inbound: message.to_h)

          if message.type != :call
            send_error(
              "Invalid message type received. Received #{message.type.quoted}, expected \"call\""
            )

            return
          end

          model = ESM::Server.find_by_public_id(@public_id)
          case message.data.function_name
          when "send_to_channel"
            ESM::Event::SendToChannel.new(model, message).run!
          else
            raise ESM::Exception::InvalidRequest, "Missing or invalid function_name provided in request"
          end
        end

        private

        def forward_to_caller(request)
          promise = @ledger.remove(request)
          raise ESM::Exception::InvalidMessage if promise.nil?

          promise.set_response(request)
        end

        def process_message(request)
          if @ledger.include?(request)
            forward_to_caller(request)
            return
          end

          case request.type
          when :identification
            on_identification(request.content)
          when :message
            on_request(request.content)
          end
        rescue ESM::Exception::ClosableError
          close
        rescue ESM::Exception::SendableError => e
          send_error(e.data)
        rescue => e
          error!(error: e)
        ensure
          @ledger.remove(request)
        end

        def authenticate!(model)
          @public_id = +model.public_id

          secret_key = +model.server_key
          @encryption = Encryption.new(secret_key)

          # Generate new nonce indices for the client
          nonce_indices = Encryption.generate_nonce_indices

          message = ESM::Message.new
            .set_type(:init)
            .set_data(indices: nonce_indices)

          # This doesn't use #send_request because it needs to hook into the promise to immediately
          # swap the nonce to the new one before the client has time to respond.
          # Ignorance is bliss but this shouldn't be a race condition due to network lag
          # "It works on my computer"
          response = write(id: message.id, type: :handshake, content: message.to_s)
            .then { |_| @encryption = Encryption.new(secret_key, nonce_indices:) }
            .wait_for_response(@config.response_timeout)

          raise ESM::Exception::RejectedPromise, response.reason if response.rejected?

          # Ledger doesn't care what object it is, so long as it responds to #id
          @ledger.remove(message)
          nil
        end

        def initialize!(model)
          message = send_request(type: :initialize)
          ESM::Event::ServerInitialization.new(self, model, message).run!

          ESM.connection_server.on_initialize(self)
        end
      end
    end
  end
end
