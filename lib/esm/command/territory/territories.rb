# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class Territories < ESM::Command::Base
        command_type :player
        command_namespace :territory, command_name: :list

        requires :registration

        change_attribute :allowed_in_text_channels, default: false

        argument :server_id, display_name: :for

        def on_execute
          deliver!(query: "list_territories", uid: current_user.steam_uid)
        end

        def on_response(_, _)
          check_for_no_territories!

          # Apparently past me I didn't default the response to an array if there was only one territory...
          @response = [@response] if @response.is_a?(OpenStruct)

          @response.each do |territory|
            reply(territory_embed(territory))
          end
        end

        #########################
        # Command Methods
        #########################
        def check_for_no_territories!
          check_failed!(:no_territories, user: current_user.mention, server_id: target_server.server_id) if @response.blank?
        end

        def territory_embed(territory)
          @territory = ESM::Exile::Territory.new(server: target_server, territory: territory)
          @territory.to_embed
        end
      end
    end
  end
end
