# frozen_string_literal: true

module ESM
  class Connection
    include ESM::Callbacks

    # These callbacks correspond to events sent from the server.
    register_callbacks :on_open, :on_close, :on_message # :on_ping, :on_pong
    add_callback :on_open, :on_open
    add_callback :on_close, :on_close
    add_callback :on_message, :on_message
    # add_callback :on_ping, :on_ping
    # add_callback :on_pong, :on_pong

    # A instance of ESM::Server
    attr_accessor :server

    def initialize(tcp_server, server_id)
      @tcp_server = tcp_server
      @server_id = server_id
    end

    delegate :server_id, to: :@server, allow_nil: true

    def close
      @tcp_server.disconnect(@server_id)
    end

    def send_message(type:, data: {}, metadata: {})
      message = ESM::Connection::Message.new(server_id: self.server_id, type: type, data: data, metadata: metadata)
      @tcp_server.send_message(message)

      ESM::Notifications.trigger("info", class: self.class, method: __method__, message: message)
    end

    private

    def on_open
      ESM::Notifications.trigger("info", class: self.class, method: __method__, server_id: self.server_id)
    end

    def on_message(message)
      ESM::Notifications.trigger("info", class: self.class, method: __method__, server_id: self.server_id, message: message.to_h)
    end

    def on_close
      ESM::Notifications.trigger("info", class: self.class, method: __method__, server_id: self.server_id)
    end

    # def on_ping(_message)
    #   ESM::Notifications.trigger("info", event: "on_ping", message: message)
    #   send_message(code: Codes::PONG)
    # end

    # def on_pong(_message)
    #   ESM::Notifications.trigger("info", event: "on_pong", message: message)

    #   @last_pong_at = ::Time.current
    # end

    # def ping_server
    #   send_message(code: Codes::PING)

    #   @last_ping_at = ::Time.current
    # end
  end
end
