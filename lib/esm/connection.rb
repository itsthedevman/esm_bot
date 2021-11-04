# frozen_string_literal: true

module ESM
  class Connection
    attr_reader :server, :version, :tcp_server

    # @return [Boolean] Returns true the connection has been initialized and is ready for use
    attr_accessor :initialized

    def initialize(tcp_server, server_id)
      @tcp_server = tcp_server
      @server = ESM::Server.find_by_server_id(server_id)
    end

    delegate :server_id, to: :@server

    # @param message [Hash, ESM::Connection::Message] This can be either a hash of arguments for ESM::Connection::Message, or an instance of it.
    def send_message(message = {}, forget: false, wait: false)
      message = ESM::Connection::Message.new(**message) if message.is_a?(Hash)

      @tcp_server.fire(message, to: self.server_id, forget: forget, wait: wait)
    end

    def disconnect
      @tcp_server.disconnect(self.server_id)
    end

    def on_open(message)
      @version = Semantic::Version.new(message.data.extension_version)
      ESM::Event::ServerInitialization.new(self, message).run!
    end

    def on_message(incoming_message, outgoing_message)
      @server.reload # Ensure the server is up-to-date
      outgoing_message&.delivered # Let the overseer know that it's good

      case incoming_message.type
      when ->(type) { type == "event" && incoming_message.data_type != "empty" }
        self.on_event(incoming_message, outgoing_message)
      else
        outgoing_message.run_callback(:on_response, incoming_message, outgoing_message)
      end
    end

    def on_close; end

    def on_event(incoming_message, _outgoing_message)
      case incoming_message.data_type
      when "send_to_channel"
        ESM::Event::SendToChannel.new(self, incoming_message).run!
      else
        raise "[#{incoming_message.id}] Connection#on_event does not implement this type: \"#{incoming_message.data_type}\""
      end
    end
  end
end
