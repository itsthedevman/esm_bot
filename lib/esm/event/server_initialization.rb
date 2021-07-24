# frozen_string_literal: true

module ESM
  module Event
    class ServerInitialization
      def initialize(connection, message)
        @connection = connection
        @server = connection.server
        @message = message
        @community = @server.community
        @discord_server = @community.discord_server
      end

      def run!
        # Updates the database with information from the server
        initialize_server

        # We need to let the DLL know some stuff (namely a lot of stuff)
        build_settings_packet

        # Send packet to server
        send_response
      end

      # Called when an admin updates some settings.
      def update
        # We need to let the DLL know some stuff (namely a lot of stuff)
        build_settings_packet

        # Send packet to server
        send_response
      end

      private

      def initialize_server
        update_server
        update_server_settings
        store_territory_data
      end

      def update_server
        @server.update!(
          server_name: @message.data.server_name,
          server_start_time: @message.data.server_start_time.utc,
          disconnected_at: nil
        )
      end

      def update_server_settings
        @server.server_setting.update(
          territory_price_per_object: @message.data.price_per_object,
          territory_lifetime: @message.data.territory_lifetime
        )
      end

      def store_territory_data
        @server.territories.delete_all

        territories =
          @message.data.territory_data.map do |data|
            {
              server_id: @server.id,
              territory_level: data[:level],
              territory_purchase_price: data[:purchase_price],
              territory_radius: data[:radius],
              territory_object_count: data[:object_count]
            }
          end

        ESM::Territory.import(territories)
      end

      def build_settings_packet
        settings = @server.server_setting
        rewards = @server.server_reward

        # Remove the database and v1 fields
        packet = settings.attributes.without(
          *%w[
            id server_id created_at updated_at deleted_at
            server_restart_hour server_restart_min request_thread_type request_thread_tick logging_path
          ]
        ).symbolize_keys

        packet = packet.merge(
          territory_payment_tax: settings.territory_payment_tax / 100,
          territory_upgrade_tax: settings.territory_upgrade_tax / 100,
          extdb_path: settings.extdb_path || "",
          territory_admins: build_territory_admins,
          reward_player_poptabs: rewards.player_poptabs,
          reward_locker_poptabs: rewards.locker_poptabs,
          reward_respect: rewards.respect,
          reward_items: rewards.reward_items
        )

        @packet = OpenStruct.new(packet)
      end

      def build_territory_admins
        # Get all roles with administrator or that are set as territory admins
        roles = @discord_server.roles.select { |role| role.permissions.administrator || @community.territory_admin_ids.include?(role.id.to_s) }

        # Get all of the user's discord IDs who have these roles
        discord_ids =
          roles.map do |role|
            role.users.map { |user| user.id.to_s }
          end.flatten

        # Pluck all the steam UIDs we have, including the guild owners
        ESM::User.where(discord_id: discord_ids + [@discord_server.owner.id.to_s]).where.not(steam_uid: nil).pluck(:steam_uid)
      end

      def send_response
        message = ESM::Connection::Message.new(server_id: @server.server_id, type: "post_init", data: @packet)
        message.add_callback("on_response") do |_message|
          # Trigger a connect notification
          ESM::Notifications.trigger("server_on_connect", server: @connection.server)

          # Set the connection to be available for commands
          @connection.ready = true
        end

        @connection.send_message(message)
      end
    end
  end
end
