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
          check_for_in_progress!

          # Check to see if the server has any rewards for the user before even sending the request
          check_for_valid_reward_id!
          check_for_reward_items!

          # Notify the user that we're sending them a direct message only if the command was from a text channel
          if current_channel.text?
            embed = ESM::Embed.new(:success, description: I18n.t("commands.reward.check_pm", user: current_user.mention))
            reply(embed)
          end

          # TODO: Skip if vg_enabled == false
          # Need some sort of method to register a command for waiting
          # This will need to cause a block to keep from having two "waiting" events for the same user+channel
          # Ideas:
          #   - Nearby spawning in forests may be problematic. Either provide serious disclaimer or may want to create "!reward esm_malden restore" vehicle command to

          @nearby_vehicles = []
          @vehicles = selected_reward.vehicles.clone
          need_spawn_locations = selected_reward.reward_vehicles.any? { |v| ["virtual_garage", "player_decides"].include?(v["spawn_location"]) }

          # Send the request description
          embed = ESM::Embed.new do |e|
            e.color = :green
            e.description = I18n.t(
              "commands.reward.reward_description",
              user: current_user.mention,
              server_id: target_server.server_id,
              reward_id: selected_reward.reward_id || "default"
            )

            e.add_field(name: "Poptabs added to player", value: "```#{selected_reward.player_poptabs.to_poptab}```", inline: true) if selected_reward.player_poptabs.positive?
            e.add_field(name: "Poptabs added to locker", value: "```#{selected_reward.locker_poptabs.to_poptab}```", inline: true) if selected_reward.locker_poptabs.positive?
            e.add_field(name: "Respect added to player", value: "```#{selected_reward.respect}```", inline: true) if selected_reward.respect.positive?
            e.add_field(value: "Once you are ready to receive the reward, just reply with `accept`") if !need_spawn_locations
            e.footer = "You can always cancel this request by replying with `cancel`"
          end

          reply(embed)
          return request_spawn_locations if need_spawn_locations

          watch_for_reply
        end

        def on_response(incoming_message)

        end

        def on_reply(event)
          if event.nil?
            embed = ESM::Embed.new(:error, description: I18n.t("commands.reward.no_reply", user: current_user.mention))
            return reply(embed)
          end

          content = event.message.content.squish
          return on_cancel if %w[quit exit stop cancel reject].include?(content.downcase)
          return on_accept if %w[done finish accept].include?(content.downcase)
          return if @vehicles.blank? # on_reply is called even if there are no vehicles

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
            previous_choice = vehicle[:chosen_location]

            # Check to make sure this territory is valid. The user can use a custom id or territory ID
            territory = @territories.find do |t|
              t.custom_id.downcase == location || t.territory_id.downcase == location
            end

            if territory && ["virtual_garage", "player_decides"].include?(vehicle[:spawn_location])
              territory.vehicle_count += 1

              vehicle[:chosen_location] = territory.custom_id || territory.territory_id
              vehicle[:territory_id] = territory.id
            elsif vehicle[:spawn_location] == "player_decides"
              vehicle[:chosen_location] = "Nearby"
              vehicle.delete(:territory_id)
            else
              next
            end

            # Increase the vehicle count because we're removing one
            if (previous_territory = @territories.find { |t| t.custom_id.downcase == previous_choice || t.territory_id.downcase == previous_choice })
              previous_territory.vehicle_count -= 1
            end

            success = true
          end

          if !success
            watch_for_reply
            event.message.react("❌")
            return
          end

          event.message.react("✅")

          watch_for_reply
          edit(@vehicle_message, vehicle_embed)
        end

        private

        def on_cancel
          reply("Oh, I see how it is")
        end

        def on_accept
          vehicles = @vehicles + @nearby_vehicles
          if vehicles.present?
            # Check to see if all vehicles have the required information
            invalid_vehicle_numbers = vehicles.map.with_index do |vehicle, index|
              next if vehicle[:territory_id].present? || (vehicle[:chosen_location] || vehicle[:spawn_location]).downcase == "nearby"

              index + 1
            end.compact

            if invalid_vehicle_numbers.present?
              reply("Yo, you forgot some. #{invalid_vehicle_numbers}")
              watch_for_reply
              return
            end

            vehicles = vehicles.map do |vehicle|
              { class_name: vehicle[:class_name], spawn_location: vehicle[:territory_id] || "nearby" }
            end
          end

          send_to_a3(
            type: "arma",
            data_type: "reward",
            data: {
              target_uid: current_user.steam_uid,
              player_poptabs: selected_reward.player_poptabs,
              locker_poptabs: selected_reward.locker_poptabs,
              respect: selected_reward.respect,
              items: selected_reward.reward_items.to_a.to_json,
              vehicles: vehicles.to_json
            }
          )
        end

        def request_spawn_locations
          @territories = user_territories.sort_by(&:territory_id)

          # They'll be added back later. We don't need a location for them
          @vehicles.reject! do |vehicle|
            @nearby_vehicles << vehicle if vehicle[:spawn_location] == "nearby"
          end

          # This is not blocking
          watch_for_reply

          @vehicle_message = reply(vehicle_embed)
        end

        def selected_reward
          @selected_reward ||= target_server.server_rewards.where(reward_id: @arguments.reward_id).first
        end

        def check_for_in_progress!
          return if !ESM.bot.reply_overseer.watching?(user_id: current_user.id, channel_id: current_channel.id)

          check_failed!(:waiting_for_reply, user: current_user.mention, command_name: self.name)
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

        def vehicle_embed
          ESM::Embed.new do |e|
            e.title = "Vehicle Configuration"
            e.description = ""
            e.add_field(name: "Spawn Locations", value: "```#{spawn_locations_table}```")
            e.add_field(name: "Vehicles", value: "```#{vehicles_table}```")
          end
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

              t.add_row([index + 1, vehicle[:chosen_location] || "Choose...", display_name])
            end
          end
        end
      end
    end
  end
end
