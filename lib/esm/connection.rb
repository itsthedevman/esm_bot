# frozen_string_literal: true

module ESM
  class Connection
    attr_reader :server
    attr_accessor :initialized

    def initialize(tcp_server, server_id)
      @tcp_server = tcp_server
      @server = ESM::Server.find_by_server_id(server_id)
    end

    delegate :server_id, to: :@server

    # @param message [Hash, ESM::Connection::Message] This can be either a hash of arguments for ESM::Connection::Message, or an instance of it.
    def send_message(message = {})
      message = ESM::Connection::Message.new(**message) if message.is_a?(Hash)

      @tcp_server.send_message(message)
    end

    def on_open(message)
      ESM::Event::ServerInitialization.new(self, message).run!
    end

    def on_message(incoming_message, outgoing_message)
      return outgoing_message.run_callback(:on_error, outgoing_message, incoming_message) if incoming_message.errors?

      case incoming_message.type
      when "event"
        self.on_event(incoming_message, outgoing_message)
      else
        ESM::Notifications.trigger("error", class: self.class, method: __method__, message: "[#{incoming_message.id}] Connection#on_message does not implement this type: \"#{incoming_message.type}\"")
      end
    end

    def on_close; end

    def on_event(incoming_message, outgoing_message)
      # Soon...
      # case message.data_type
      # else
      # end

      # Acknowledge the message
      outgoing_message.run_callback(:on_response, incoming_message, outgoing_message)
      outgoing_message.delivered
    end
  end
end
