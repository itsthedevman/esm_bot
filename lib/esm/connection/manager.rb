# frozen_string_literal: true

module ESM
  class Connection
    class Manager
      ManagedConnection = Struct.new(:server_id, :connection, :last_checked_at) do
        delegate :close, :alive?, :authenticated?, to: :connection, allow_nil: true

        def needs_checked?
          check_interval =
            if self.server_id.nil?
              ESM.config.loops.connection_manager.unauthenticated.check_every
            else
              ESM.config.loops.connection_manager.authenticated.check_every
            end

          (self.last_checked_at + check_interval.seconds) < ::Time.current
        end
      end

      def initialize
        # An array of any connection that hasn't provided a handshake
        # Connections in this array will not stay for very long. They should either authenticate or they'll be dropped
        @unauthenticated = []

        # A hash with the key of a server ID and the value of the connection. Connections in this hash have been authenticated and associated with a server
        @authenticated = {}

        # @check_thread =
        #   Thread.new do
        #     loop do
        #       check_connections
        #       sleep(ESM.config.loops.connection_manager.check_every)
        #     end
        #   end
      end

      def add_unauthenticated(connection)
        @unauthenticated << ManagedConnection.new(nil, connection, ::Time.current)
      end

      def associate(server_id, connection)
        # Remove the managed_connection from the unauthenticated and move it to the authenticated
        managed_connection = @unauthenticated.reject! { |managed_conn| managed_conn.connection.equal?(connection) }.first
        return if managed_connection.blank?

        managed_connection.server_id = server_id

        # Associate the server_id and the resource_id
        @resource_ids[connection.resource_id] = server_id

        # Associate the server_id to the managed connection
        @authenticated[server_id] = managed_connection
      end

      def find_by_server_id(server_id)
        return if !@authenticated.key?(server_id)

        @authenticated[server_id].connection
      end

      def find_by_resource_id(resource_id)
        server_id = @resource_ids[resource_id]
        return if server_id.nil?

        self.find_by_server_id(server_id)
      end

      private

      def check_connections
        # Check to see if the unauthenticated have authenticated yet. Drop them if they haven't
        @unauthenticated.each do |managed_connection|
          next if !managed_connection.needs_checked?
          next if managed_connection.authenticated?

          ESM.logger.debug("#{self.class}##{__method__}") { "Closing unauthenticated connection: #{managed_connection}" }
          managed_connection.close
          @unauthenticated.delete(managed_connection)
        end

        # Check to see if the authenticated are still connected. Drop the connection if it's dead.
        @authenticated.each do |server_id, managed_connection|
          next if !managed_connection.needs_checked?
          next if managed_connection.alive?

          ESM.logger.debug("#{self.class}##{__method__}") { "Closing #{server_id}'s connection: #{managed_connection}" }
          managed_connection.close
          @authenticated.delete(server_id)
        end
      end
    end
  end
end
