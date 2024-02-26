# frozen_string_literal: true

module ESM
  module Connection
    class Server
      ################################
      # Class methods
      ################################
      class << self
        delegate :disconnect_all!, :pause, :resume, to: :@instance, allow_nil: true

        def run!
          @instance = new
          @instance.start
        end

        def stop!
          return true if @instance.nil?

          @instance.stop
          @instance = nil
        end
      end

      ################################
      # Instance methods
      ################################
      def initialize
        @ledger = Ledger.new
        @connections = Concurrent::Map.new
        @status = Inquirer.new(:stopped, :paused, :started, default: :stopped)
      end

      def start
        @server = TCPServer.new("0.0.0.0", ESM.config.ports.connection_server)

        check_every = ESM.config.loops.connection_server.check_every
        @task = Concurrent::TimerTask.execute(execution_interval: check_every) { on_connect }

        @status.set(:started)
        info!(status: @status)
      end

      def stop
        @status.set(:stopped)
        @connections.each(&:close)

        @server.shutdown(:RDWR)
      end

      private

      def on_connect
        return unless @status.started?

        client = Client.new(self, @server.accept, @ledger)
        @waiting_room << client
      end
    end
  end
end
