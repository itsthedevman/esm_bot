# frozen_string_literal: true

module ESM
  class Connection
    class Manager
      ManagedConnection = Struct.new(:connection, :last_checked_at) do
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
        # Lookup tables of connections
        @resource_ids = {}
        @server_ids = {}

        # Contains ResourceIDs (integers)
        @unauthenticated = []
        @authenticated = []

        @check_thread =
          Thread.new do
            loop do
              check_connections
              sleep(ESM.config.loops.connection_manager.check_every)
            end
          end
      end

      def add_unauthenticated(resource_id, connection)
        connection = ManagedConnection.new(connection, ::Time.current)
        @resource_ids[resource_id] = connection
        @unauthenticated << resource_id
      end

      def associate(resource_id, server_id)
        if !@unauthenticated.include?(resource_id)
          ESM::Notifications.trigger(
            "error",
            class: self.class,
            method: __method__,
            resource_id: resource_id,
            server_id: server_id,
            message: "[BUG] Already associated. Why is this being called again?"
          )

          return
        end

        managed_connection = @resource_ids[resource_id]
        return if managed_connection.blank?

        # Associate the server_id with the managed connection
        @server_ids[server_id] = managed_connection

        # Mark that this resource has been authenticated
        @unauthenticated.delete(resource_id)
        @authenticated << resource_id
      end

      def find_by_server_id(server_id)
        managed_connection = @server_ids[server_id]
        return if managed_connection.nil?

        managed_connection.connection
      end

      def find_by_resource_id(resource_id)
        managed_connection = @resource_ids[resource_id]
        return if managed_connection.nil?

        managed_connection.connection
      end

      private

      def check_connections
        # Check to see if the unauthenticated have authenticated yet. Drop them if they haven't
        @unauthenticated.each do |resource_id|
          managed_connection = self.find_by_resource_id(resource_id)
          next if !managed_connection.needs_checked?
          next if managed_connection.authenticated?

          ESM.logger.debug("#{self.class}##{__method__}") { "Closing unauthenticated connection: #{managed_connection}" }
          managed_connection.close
          @unauthenticated.delete(managed_connection)
        end

        # Check to see if the authenticated are still connected. Drop the connection if it's dead.
        @authenticated.each do |resource_id|
          managed_connection = self.find_by_resource_id(resource_id)
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
