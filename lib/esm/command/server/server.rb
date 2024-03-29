# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Server < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :for

        #
        # Configuration
        #

        command_namespace :server, command_name: :details
        command_type :player

        does_not_require :registration

        # Reason: It's nice accessing the connection info even when it is offline
        skip_action :connected_server

        #################################

        def on_execute
          embed =
            ESM::Embed.build do |e|
              e.title = target_server.server_name
              e.color = target_server.connected? ? :green : :red

              if !target_server.connected?
                e.description =
                  if target_server.disconnected_at.nil?
                    I18n.t("commands.servers.offline")
                  else
                    I18n.t("commands.servers.offline_for", time: target_server.time_since_last_connection)
                  end
              end

              # Server ID, IP, port, status
              add_connection_info(e)

              # Map, players, game version
              add_server_info(e)

              # Mods
              add_server_mods(e)
            end

          reply(embed)
        end

        #########################
        # Command Methods
        #########################
        def query_server
          # I store the connection port. Query port is always +1
          server = SourceServer.new(IPAddr.new(target_server.server_ip), target_server.server_port.to_i + 1)

          # Connect to the server
          server.init

          # This contains:
          #     :protocol_version, :server_name, :map_name, :game_directory, :game_description, :app_id, :number_of_players,
          #     :max_players, :number_of_bots, :dedicated, :operating_system, :password_needed, :secure, :game_version, :server_port,
          #     :server_id, :server_tags, :game_id
          server.server_info.to_istruct
        rescue
          nil
        end

        def add_connection_info(e)
          e.add_field(name: I18n.t(:server_id), value: "```#{target_server.server_id}```")
          e.add_field(name: I18n.t(:ip), value: "```#{target_server.server_ip}```", inline: true)
          e.add_field(name: I18n.t(:port), value: "```#{target_server.server_port}```")
          return unless target_server.connected?

          e.add_field(name: I18n.t("commands.server.online_for"), value: "```#{target_server.uptime}```")
          e.add_field(name: I18n.t("commands.server.restart_in"), value: "```#{target_server.time_left_before_restart}```")
        end

        def add_server_info(e)
          query_response = query_server
          return if query_response.nil?

          e.add_field(name: I18n.t(:map), value: query_response.map_name, inline: true)
          e.add_field(name: I18n.t(:players), value: "#{query_response.number_of_players}/#{query_response.max_players}", inline: true)
          e.add_field(name: I18n.t(:game_version), value: query_response.game_version, inline: true)
        end

        def add_server_mods(e)
          return if target_server.server_mods.blank?

          grouped_mods = target_server.server_mods.group_by { |mod| mod.mod_required? ? I18n.t(:required_mods) : I18n.t(:optional_mods) }
          grouped_mods.each do |header, mods|
            mod_field = {name: header, value: [], inline: true}
            process_mods(e, mod_field, mods)
          end
        end

        def process_mods(e, mod_field, mods)
          mods.each do |mod|
            # If we have a mod_link, convert that to be a hyperlink
            mod_line =
              if mod.mod_link.blank?
                "#{mod.mod_name} #{mod.mod_version}"
              else
                "[#{mod.mod_name} #{mod.mod_version}](#{mod.mod_link})"
              end

            # If the owner added more mods than our field can hold, send it and create a new field
            if (mod_field[:value].total_size + mod_line.size) > ESM::Embed::Limit::FIELD_VALUE_LENGTH_MAX
              e.add_field(**mod_field)
              mod_field = {name: "#{mod_field[:name]} #{I18n.t(:continued)}", value: [], inline: true}
            end

            mod_field[:value] << mod_line
          end

          e.add_field(**mod_field)
        end
      end
    end
  end
end
