# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Reward < ESM::Command::Base
        type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds # Don't allow adjusting this cooldown. Each reward has it's own cooldown

        argument :server_id

        # Since it shares a similar structure to server_id, we can use server_id's before_store callback to allow auto-filling the community_id
        argument :reward_id, regex: ESM::Regex::REWARD_ID_OPTIONAL_COMMUNITY, template: :server_id, default: nil

        # FOR DEV ONLY
        skip_check :cooldown

        def on_execute
          # Check for pending requests
          @checks.pending_request!

          # Check to see if the server has any rewards for the user before even sending the request
          check_for_valid_reward_id!
          check_for_reward_items!

          # Notify the user that we're sending them a direct message only if the command was from a text channel
          if current_channel.text?
            embed = ESM::Embed.build(:success, description: I18n.t("commands.reward.check_pm", user: current_user.mention))
            reply(embed)
          end

          # We need to know where the player wants to store their spawns
          # TODO: Skip if vg_enabled == false
          # Ideas:
          #   - Nearby spawning in forests may be problematic. Either provide serious disclaimer or may want to create "!reward esm_malden restore" vehicle command to

          @nearby_vehicles = []
          @vehicles = selected_reward.vehicles.clone
          return capture_vehicle_data if selected_reward.reward_vehicles.any? { |v| ["virtual_garage", "player_decides"].include?(v["spawn_location"]) }



          # This command:
          #   add method for processing data to create request.
          #   add method for on_incoming_message
          #
          # bot:
          #   associate the channel and user to this command instance
          #   bind on message for bot to check for those two values
          #   pull the command from memory and call #on_reply, passing in the event
          #
          # Need some sort of method to register a command for waiting
          # This will need to cause a block to keep from having two "waiting" events for the same user+channel

          # reply(
          #   I18n.t(
          #     "commands.reward.request_description",
          #     user: current_user.mention,
          #     server_id: target_server.server_id,
          #     rewards: selected_reward.itemize,
          #     reward_id: selected_reward.reward_id || "default"
          #   )
          # )


          # response = ESM.bot.await_response(current_user, expected: [I18n.t("yes"), I18n.t("no")], timeout: 120)
          # return reply(I18n.t("commands.broadcast.cancelation_reply")) if response.nil? || response.downcase == I18n.t("no").downcase
          confirm_reward
        end

        def confirm_reward
          @vehicles += @nearby_vehicles

          binding.pry
           # reply(
          #   I18n.t(
          #     "commands.reward.request_description",
          #     user: current_user.mention,
          #     server_id: target_server.server_id,
          #     rewards: selected_reward.itemize,
          #     reward_id: selected_reward.reward_id || "default"
          #   )
          # )
        end

        def on_response(incoming_message)

        end

        def on_reply(event)
          if event.nil?
            embed = ESM::Embed.build(:error, description: I18n.t("commands.reward.no_reply", user: current_user.mention))
            return reply(embed)
          end

          content = event.message.content.squish
          return confirm_reward if %w[quit exit done stop].include?(content)

          # The message is formatted correctly
          if !content.match?(/(\d+:\w+)+/i)
            watch_for_reply
            event.message.react("❌")
            return
          end

          # Supports one at a time or multiple
          location_data = event.message.content.split.map { |s| s.split(":") }

          success = false
          location_data.each do |index, location|
            index = [index.to_i - 1, 0].max
            vehicle = @vehicles[index]
            next if vehicle.nil?

            location = location.downcase
            previous_choice = vehicle[:choice]

            # Check to make sure this territory is valid. The user can use a custom id or territory ID
            territory = @territories.find do |t|
              t.custom_id.downcase == location || t.territory_id.downcase == location
            end

            if territory && ["virtual_garage", "player_decides"].include?(vehicle[:spawn_location])
              territory.vehicle_count = [territory.vehicle_count - 1, 0].max
              vehicle[:choice] = territory.custom_id || territory.territory_id
            elsif vehicle[:spawn_location] == "player_decides"
              vehicle[:choice] = "Nearby"
            else
              next
            end

            # Increase the vehicle count because we're removing one
            if (previous_territory = @territories.find { |t| t.custom_id.downcase == previous_choice || t.territory_id.downcase == previous_choice })
              previous_territory.vehicle_count += 1
            end

            success = true
          end

          if !success
            watch_for_reply
            event.message.react("❌")
            return
          end

          event.message.react("✅")

          embed = ESM::Embed.build do |e|
            e.title = "Before I can process your reward"
            e.description = "Some of the vehicles in this reward allow you to pick where they spawn.\nTo set the locations of the vehicles, please reply back "
            e.add_field(name: "Spawn Locations", value: "```#{spawn_locations_table}```")
            e.add_field(name: "Vehicles", value: "```#{vehicles_table}```")
          end

          watch_for_reply

          edit(@vehicle_message, embed)
        end

        def request_accepted
          send_to_a3(
            target_uid: current_user.steam_uid,
            reward_items: selected_reward.reward_items.to_a,
            reward_vehicles: selected_reward.reward_vehicles,
            locker_poptabs: selected_reward.locker_poptabs,
            player_poptabs: selected_reward.player_poptabs,
            respect: selected_reward.respect
          )
        end

        private

        def capture_vehicle_data
          @territories = user_territories.sort_by(&:territory_id)

          # Don't capture data for nearby vehicles
          @vehicles.reject! do |vehicle|
            @nearby_vehicles << vehicle if vehicle[:spawn_location] == "nearby"
          end

          embed = ESM::Embed.build do |e|
            e.title = "Before I can process your reward"
            e.description = "Some of the vehicles in this reward allow you to pick where they spawn.\nTo set the locations of the vehicles, please reply back "
            e.add_field(name: "Spawn Locations", value: "```#{spawn_locations_table}```")
            e.add_field(name: "Vehicles", value: "```#{vehicles_table}```")
          end

          # This is not blocking
          watch_for_reply

          @vehicle_message = reply(embed)
        end

        def selected_reward
          @selected_reward ||= target_server.server_rewards.where(reward_id: @arguments.reward_id).first
        end

        def check_for_valid_reward_id!
          return if selected_reward.present?

          check_failed!(:incorrect_reward_id, user: current_user.mention, reward_id: @arguments.reward_id)
        end

        def check_for_reward_items!
          return if selected_reward.reward_items.present? ||
                    selected_reward.reward_vehicles.present? ||
                    selected_reward.locker_poptabs.positive? ||
                    selected_reward.player_poptabs.positive? ||
                    selected_reward.respect.positive?

          check_failed!(:no_reward_items, user: current_user.mention)
        end

        def watch_for_reply
          ESM.bot.watch(user_id: current_user.id, channel_id: current_channel.id) { |event| self.on_reply(event) }
        end

        #
        # Sends a request to the server to retrieve this player's territory data
        #
        def user_territories
          @user_territories ||= lambda do
            response = target_server.connection.send_message_sync(
              type: "query",
              data: {
                name: "reward_territories",
                arguments: {
                  uid: current_user.steam_uid
                }
              }
            )

            if response.errors?
              ESM::Notifications.trigger("error", class: self.class, method: __method__, id: response.id, errors: response.errors)
              check_failed!(:territory_query, user: current_user.mention, server_id: target_server.server_id)
            end

            # {
            #   id: Integer,
            #   custom_id: String,
            #   name: String,
            #   level: Integer,
            #   vehicle_count: Integer,
            # }
            response.data.results.map do |territory|
              territory[:territory_id] = territory["custom_id"] || target_server.encode_id(territory[:id]).upcase
              OpenStruct.new(territory)
            end
          end.call
        end

        def spawn_locations_table
          Terminal::Table.new do |t|
            t.style = {
              width: 63,
              border: :unicode,
              border_top: false,
              border_right: false,
              border_bottom: false,
              border_left: false
            }

            t.headings = ["Territory ID", "Name", "Free Spots"]

            t.add_row(["Nearby", "Spawn near player", "∞"])

            max_size_lookup = target_server.metadata.vg_max_sizes.to_a
            @territories.each do |territory|
              max_size = max_size_lookup[territory.level]
              free_spots =
                if territory.vehicle_count >= max_size
                  "full"
                else
                  max_size - territory.vehicle_count
                end

              t.add_row([territory.custom_id || territory.territory_id, territory.name, free_spots])
            end
          end
        end

        def vehicles_table
          Terminal::Table.new do |t|
            t.style = {
              border: :unicode,
              width: 63,
              border_top: false,
              border_right: false,
              border_bottom: false,
              border_left: false
            }

            t.headings = ["Vehicle #", "Location", "Vehicle Name"]

            @vehicles.each_with_index do |vehicle, index|
              display_name =
                if vehicle[:spawn_location] == "virtual_garage"
                  "#{vehicle[:display_name]} (VG ONLY)"
                else
                  vehicle[:display_name]
                end

              t.add_row([index + 1, vehicle[:choice] || "Choose...", display_name])
            end

            t.align_column(0, :right)
          end
        end
      end
    end
  end
end
