# frozen_string_literal: true

module ESM
  module Connection
    class Client
      module Lifecycle
        def on_identification(public_id)
          info!(address:, state: :on_identification, public_id:)

          @model = ESM::Server.find_by_public_id(public_id)
          raise ESM::Exception::InvalidAccessKey if @model.nil?
          raise ESM::Exception::ExistingConnection if @model.connected?

          authenticate!
          initialize!
        end

        def on_request(content)
          message = ESM::Message.from_string(content)

          # Handle any errors
          if message.errors?
            error!(errors: message.error_messages.join("\n"))
            return
          end

          @model.reload

          case message.data_type
          when :send_to_channel
            ESM::Event::SendToChannel.new(@model, message).run!
          else
            raise "Invalid data received: #{message}"
          end
        rescue => e
          error!(error: e)
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
        rescue Error => e
          send_error(e)
          close
        rescue => e
          error!(error: e)
        ensure
          @ledger.remove(request)
        end

        def authenticate!
          @id = @model.public_id
          @encryption = Encryption.new(@model.token[:secret])

          nonce_indices = Encryption.generate_nonce_indices
          message = ESM::Message.new.set_data(:handshake, indices: nonce_indices)

          # This doesn't use #send_request because it needs to hook into the promise to immediately
          # swap the nonce to the new one before the client has time to respond.
          # Ignorance is bliss but this shouldn't be a race condition due to network lag
          # "It works on my computer"
          response = write(id: message.id, type: :handshake, content: message.to_s)
            .then { |_| @encryption = Encryption.new(@model.token[:secret], nonce_indices:) }
            .wait_for_response(@config.response_timeout)

          raise ESM::Exception::RejectedRequest, response.reason if response.rejected?

          # Ledger doesn't care what object it is, so long as it responds to #id
          @ledger.remove(message)
          nil
        end

        def initialize!
          message = send_request(type: :initialize)
          ESM::Event::ServerInitialization.new(self, message).run!

          ESM.connection_server.on_initialize(self)
        end
      end
    end
  end
end
