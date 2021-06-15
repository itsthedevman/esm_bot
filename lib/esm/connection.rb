# frozen_string_literal: true

module ESM
  class Connection
    include ESM::Callbacks

    # These callbacks correspond to events sent from the server.
    register_callbacks :on_open, :on_close, :on_message
    add_callback :on_open, :on_open
    add_callback :on_close, :on_close
    add_callback :on_message, :on_message

    attr_reader :server

    def initialize(tcp_server, server_id, resource_id)
      @tcp_server = tcp_server
      @server = ESM::Server.find_by_server_id(server_id)
      @resource_id = resource_id
    end

    delegate :server_id, to: :@server

    def send_message(**args)
      @tcp_server.send_message(**args.merge(server_id: self.server_id))
    end

    private

    def on_open

    end

    def on_message(message)

    end

    def on_close

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
