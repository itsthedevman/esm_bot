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

    module Code
      CLOSE = 0
      CONNECT = 1
      PING = 2
      PONG = 3
      MESSAGE = 4
      ERROR = 5
    end

    def initialize(server, resource_id)
      @tcp_server = server
      @resource_id = resource_id
      @status = :unauthenticated
    end

    delegate :server_id, to: :@server, allow_nil: true

    def close
      @tcp_server.disconnect(@resource_id)
    end

    def send_message(**data)
      ESM::Notifications.trigger("info", class: self.class, method: __method__, message: data)
      @tcp_server.send_message(@resource_id, type: "test", data: data)
    end

    def alive?
      true
    end

    def stale?
      @last_pong_at < 10.seconds.ago
    end

    def authenticated?
      @status == :authenticated
    end

    private

    def on_open
      # If the server is already connected, don't allow it to connect again
      raise ESM::Exception::FailedAuthentication, "This server is already connected" if self.server.connected?

      @tcp_server.connections.authenticate(@resource_id, self.server_id)
      ESM::Notifications.trigger("info", class: self.class, method: __method__, resource_id: @resource_id, server_id: self.server_id)

      @status = :authenticated
    end

    def on_message(message)
      ESM::Notifications.trigger("info", class: self.class, method: __method__, resource_id: @resource_id, message: message.to_h)
    end

    def on_close
      ESM::Notifications.trigger("info", class: self.class, method: __method__, resource_id: @resource_id, server_id: self.server_id, event: "on_close")
      @status = :close
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
