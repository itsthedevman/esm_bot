# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Info < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::DEFAULTS[:target]
        # Optional: This command works for players or territories
        argument :target, required: false, display_name: :whom

        # See Argument::DEFAULTS[:territory_id]
        # Optional: This command works for players or territories
        argument :territory_id, required: false, display_name: :territory

        # See Argument::DEFAULTS[:server_id]
        argument :server_id, display_name: :on

        #
        # Configuration
        #

        change_attribute :allowlist_enabled, default: true

        command_namespace :server, :admin, command_name: :find
        command_type :admin

        limit_to :text

        #################################

        def on_execute
          # Ensure we were given a target or territory ID
          check_for_no_target!

          # Territory ID takes priority since both arguments are optional, and both can be provided
          # Reasoning: Given the weird scenario, user gives a mention plus a territory ID thinking that it will do some filter...
          if arguments.territory_id.present?
            deliver!(query: "territory_info", territory_id: arguments.territory_id)
          else
            deliver!(query: "player_info", uid: target_user.steam_uid)
          end
        end

        def on_response(_, _)
          # I'm not quite sure if this is needed, but just in case...
          check_for_response!

          # The fact that it has an ID indicates it was a territory...
          if @response.id
            territory = ESM::Exile::Territory.new(server: target_server, territory: @response)
            reply(territory.to_embed)
          else
            player = ESM::Exile::Player.new(server: target_server, player_data: @response)
            reply(player.to_embed)
          end
        end

        private

        def check_for_no_target!
          check_failed!(:no_target, user: current_user.mention) if arguments.target.nil? && arguments.territory_id.nil?
        end

        def check_for_response!
          return if @response.present?

          check_failed!(:no_response, user: current_user.mention)
        end
      end
    end
  end
end
