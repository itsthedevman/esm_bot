# frozen_string_literal: true

module ESM
  class Connection
    include ESM::Callbacks

    # These callbacks correspond to events sent from the server.
    register_callbacks :on_open, :on_close, :on_ping, :on_pong, :on_message
    add_callback :on_open, :on_open
    add_callback :on_close, :on_close
    add_callback :on_ping, :on_ping
    add_callback :on_pong, :on_pong
    add_callback :on_message, :on_message

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
      @connection_server = server
      @resource_id = resource_id
      @status = :unauthenticated
    end

    def close
      @connection_server.close(@resource_id)
    end

    def send_message(**data)
      ESM::Notifications.trigger("info", class: self.class, method: __method__, message: data)
    end

    def alive?
      ping_server if stale?

      true
    rescue StandardError => e
      ESM.logger.debug("#{self.class}##{__method__}") { e }
      false
    end

    def stale?
      @last_pong_at < 10.seconds.ago
    end

    def authenticated?
      @status == :authenticated
    end

    private

    def on_open(_message)
      # If the server is already connected, don't allow it to connect again
      raise ESM::Exception::FailedAuthentication, "This server is already connected" if @server.connected?

      ESM::Connection::Manager.associate_connection(@server.server_id, self)
      ESM::Notifications.trigger("info", event: "on_open", address: self.address, server_id: @server.server_id)

      @status = :opened

      send_message(code: 1, message: "ee3686ece9e84c9ba4ce86182dff487f87c0a2a5004145bfb3e256a3d96ab6f01d7c6ca0a48240c29f365e10eca3ee55edb333159c604dff815ec74cba72658a553461649c554e47ab20693a1079d1c6bf8718220d704366ab315b6b3a4cbbac6b82ac2c2f3c469f9a25e134baa0df9d", another: "ee3686ece9e84c9ba4ce86182dff487f87c0a2a5004145bfb3e256a3d96ab6f01d7c6ca0a48240c29f365e10eca3ee55edb333159c604dff815ec74cba72658a553461649c554e47ab20693a1079d1c6bf8718220d704366ab315b6b3a4cbbac6b82ac2c2f3c469f9a25e134baa0df9d", lots_of_data: "ee3686ece9e84c9ba4ce86182dff487f87c0a2a5004145bfb3e256a3d96ab6f01d7c6ca0a48240c29f365e10eca3ee55edb333159c604dff815ec74cba72658a553461649c554e47ab20693a1079d1c6bf8718220d704366ab315b6b3a4cbbac6b82ac2c2f3c469f9a25e134baa0df9d")
    end

    def on_close
      ESM::Notifications.trigger("info", event: "on_close")
      @status = :close
    end

    def on_ping(_message)
      ESM::Notifications.trigger("info", event: "on_ping", message: message)
      send_message(code: Codes::PONG)
    end

    def on_pong(_message)
      ESM::Notifications.trigger("info", event: "on_pong", message: message)

      @last_pong_at = ::Time.current
    end

    def on_message(message)
      ESM::Notifications.trigger("info", event: "Inbound Message", address: self.address, server_id: @server&.server_id, message: message)

      # Every message must have the key provided
      authenticate!(message)

      case message.code
      when Code::CONNECT
        run_callback(:on_open, message)
      when Code::PONG
        run_callback(:on_pong, message)
      when Code::MESSAGE
        run_callback(:on_message, message)
      else
        # ESM::Notifications.trigger("connection_invalid_code", connection: @connection, message: message)
        send_message(code: Code::CLOSE, message: "Invalid code")
      end
    rescue Errno::EPIPE # Connection drop
      nil
    rescue ESM::Exception::FailedAuthentication, StandardError => e
      message =
        if e.is_a?(StandardError)
          "Server error occurred"
        else
          e.message
        end

      ESM::Notifications.trigger(
        "error",
        class: self.class,
        method: __method__,
        error: e,
        # address: @connection.peeraddr[2..3],
        server_id: @server&.server_id,
        status: @status
      )

      send_message(code: Code::CLOSE, message: message)
      # return
    end

    def ping_server
      send_message(code: Codes::PING)

      @last_ping_at = ::Time.current
    end
  end
end
