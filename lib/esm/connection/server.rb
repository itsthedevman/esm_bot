# frozen_string_literal: true

module ESM
  class Connection
    class Server
      include ESM::Callbacks

      # These callbacks correspond to events sent from the TCPServer
      register_callbacks :on_open, :on_close, :on_ping, :on_pong, :on_message

      ################################
      # Class methods
      ################################

      def self.run!
        @instance = self.new
        ESM::Connection::Manager.init
      end

      def self.stop!
        return if @instance.nil?

        @instance.stop_server
      end

      ################################
      # Instance methods
      ################################

      attr_reader :server

      def initialize
        @workers = []
        Rutie.new(:tcp_server, lib_path: "crates/tcp_server/target/release").init('esm_tcp_server', ESM.root)

        # These are calls to the tcp_server extension.
        @server = ::ESM::TCPServer.new(self)
        @server.listen(ENV["CONNECTION_SERVER_PORT"])
        @server.process_requests
      end

      def send_message(server_id, message)
        # Get resource_id via server_id
        # Send message to extension
        # @server.send_message(adapter_id, message) #-> Can raise ESM::Exception::ServerNotConnected
      end

      def stop_server
        return if @server.nil?

        @workers.each { |worker| Thread.kill(worker) }
        @server.stop
      end

      def on_open(resource_id)
        ESM.logger.debug("#{self.class}##{__method__}") { "on open #{resource_id}" }
        @server.send_message(resource_id, "Hey yo!")
      end
    end
  end
end
