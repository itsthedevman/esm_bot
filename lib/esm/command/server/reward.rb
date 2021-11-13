# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Reward < ESM::Command::Base
        # TODO:
        #   - Add cooldown support
        #   - Skip collecting VG data if vg_enabled is false
        #   - Improve embeds and user experience
        #   - Change separator to space for vehicle spawn locations
        #   - Add translations for all strings
        #

        # Command entry points
        #   1. Command is executed (#on_execute)
        #         Ask for vehicle spawn locations (#request_spawn_locations)
        #         Ask for confirmation (#await_for_reply)
        #
        #   2. User replies back (#on_reply)
        #         Accept word                   -> Send request to arma (#on_accept)
        #         Cancel word                   -> Confirm cancellation (#on_cancel)
        #         Territory and spawn location  -> Store data and repeat (#store_vehicle_location)
        #
        #   3. Server response back (#on_response)
        #         TODO
        #
        type :player
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds # Don't allow adjusting this cooldown. Each reward has it's own cooldown

        argument :server_id
        argument :reward_id, description: I18n.t("commands.reward.arguments.reward_id"), regex: ESM::Regex::REWARD_ID, default: nil

        SPAWN_LOCATIONS = ["virtual_garage", "player_decides"].freeze

        # FOR DEV ONLY
        skip_check :cooldown

        def on_execute
          check_for_in_progress!

          # Check to see if the server has any rewards for the user before even sending the request
          check_for_valid_reward_id!
          check_for_reward_items!

          # Notify the user that we're sending them a direct message only if the command was from a text channel
          if current_channel.text?
            embed = ESM::Embed.new(:success, description: t("commands.reward.check_pm", user: current_user.mention))
            reply(embed)
          end

          @nearby_vehicles = []
          @vehicles = selected_reward.vehicles.clone
          @locations = selected_reward.reward_vehicles.group_by { |v| v["spawn_location"] }.transform_values(&:size)
          need_spawn_locations = SPAWN_LOCATIONS.any? { |location| @locations.key?(location) }

          # Send the request description
          embed = ESM::Embed.new do |e|
            e.color = :green
            e.description = t(
              "information_embed.description",
              user: current_user.mention,
              server_id: target_server.server_id,
              reward_id: selected_reward.reward_id || "default"
            )

            if selected_reward.player_poptabs.positive?
              translation_name = "information_embed.fields.player_poptabs"
              e.add_field(name: t("#{translation_name}.name"), value: t("#{translation_name}.value", poptabs: selected_reward.player_poptabs.to_poptab), inline: true)
            end

            if selected_reward.locker_poptabs.positive?
              translation_name = "information_embed.fields.locker_poptabs"
              e.add_field(name: t("#{translation_name}.name"), value: t("#{translation_name}.value", poptabs: selected_reward.locker_poptabs.to_poptab), inline: true)
            end

            if selected_reward.respect.positive?
              translation_name = "information_embed.fields.respect"
              e.add_field(name: t("#{translation_name}.name"), value: t("#{translation_name}.value", respect: selected_reward.respect), inline: true)
            end

            e.add_field(value: t("information_embed.fields.accept")) if !need_spawn_locations
            e.footer = t("information_embed.footer")
          end

          reply(embed)
          return request_spawn_locations if need_spawn_locations

          await_for_reply
        end

        def on_response(incoming_message)
          binding.pry
        end

        def on_reply(event)
          if event.nil?
            embed = ESM::Embed.new(:error, description: t("commands.reward.no_reply", user: current_user.mention))
            return reply(embed)
          end

          content = event.message.content.squish
          return on_cancel if %w[quit exit stop cancel reject].include?(content.downcase)
          return on_accept if %w[done finish accept].include?(content.downcase)
          return if @vehicles.blank? # on_reply is called even if there are no vehicles

          # The message is formatted correctly
          if !content.match?(/(\d+:\w+)+/i)
            await_for_reply
            event.message.react("❌")
            return
          end

          store_vehicle_location(event)
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
              next if vehicle[:territory_id].present? || (vehicle[:chosen_location] || vehicle[:spawn_location]).casecmp?("nearby")

              index + 1
            end.compact

            if invalid_vehicle_numbers.present?
              reply("Yo, you forgot some. #{invalid_vehicle_numbers}")
              await_for_reply
              return
            end

            vehicles = vehicles.map do |vehicle|
              Arma::HashMap.new({ class_name: vehicle[:class_name], spawn_location: vehicle[:territory_id] || "nearby" })
            end
          end

          send_to_a3(
            type: "arma",
            data_type: "reward",
            data: {
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

          await_for_reply
          @vehicle_message = reply(vehicle_embed)
        end

        def selected_reward
          @selected_reward ||= target_server.server_rewards.where(reward_id: @arguments.reward_id).first
        end

        def check_for_in_progress!
          return if !ESM.bot.waiting_for_reply?(user_id: current_user.id, channel_id: current_channel.id)

          raise_error!(:waiting_for_reply, user: current_user.mention, command_name: self.name)
        end

        def check_for_valid_reward_id!
          return if selected_reward.present?

          raise_error!(:incorrect_reward_id, user: current_user.mention, reward_id: @arguments.reward_id)
        end

        def check_for_reward_items!
          return if selected_reward.reward_items.present? ||
                    selected_reward.reward_vehicles.present? ||
                    selected_reward.locker_poptabs.positive? ||
                    selected_reward.player_poptabs.positive? ||
                    selected_reward.respect.positive?

          raise_error!(:no_reward_items, user: current_user.mention)
        end

        def await_for_reply
          Thread.new do
            ESM.bot.wait_for_reply(user_id: current_user.id, channel_id: current_channel.id) { |event| self.on_reply(event) }
          end
        end

        #
        # Sends a request to the server to retrieve this player's territory data
        #
        def user_territories
          @user_territories ||= lambda do
            response = target_server.connection.send_message(
              {
                type: "query",
                data: {
                  name: "reward_territories",
                  arguments: {
                    uid: current_user.steam_uid
                  }
                }
              },
              wait: true
            )

            if response.errors?
              ESM::Notifications.trigger("error", class: self.class, method: __method__, id: response.id, errors: response.errors)
              raise_error!(:territory_query, user: current_user.mention, server_id: target_server.server_id)
            end

            return [] if response.data.results.blank?

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
              max_size = max_size_lookup[territory.level].to_i

              free_spots =
                if territory.vehicle_count >= max_size
                  "full"
                else
                  max_size - territory.vehicle_count
                end

              t.add_row([territory.custom_id || territory.territory_id, territory.name.truncate(60), free_spots])
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
                  "#{vehicle[:display_name].truncate(60)} (VG ONLY)"
                else
                  vehicle[:display_name].truncate(80)
                end

              t.add_row([index + 1, vehicle[:chosen_location] || "Choose...", display_name])
            end
          end
        end

        def store_vehicle_location(event)
          # Supports one at a time or multiple
          location_data = event.message.content.split.map { |s| s.split(":") }

          success = false
          location_data.each do |vehicle_index, location|
            vehicle_index = [vehicle_index.to_i - 1, 0].max
            vehicle = @vehicles[vehicle_index]
            next if vehicle.nil?

            # Check to make sure this territory is valid. The user can use a custom id or territory ID
            location = location.downcase
            territory = @territories.find { |t| location.casecmp?(t.custom_id) || location.casecmp?(t.territory_id) }

            # Store the location on the vehicle
            previous_choice = vehicle[:chosen_location]
            if territory && SPAWN_LOCATIONS.include?(vehicle[:spawn_location])
              territory.vehicle_count += 1

              vehicle[:chosen_location] = territory.custom_id || territory.territory_id
              vehicle[:territory_id] = territory.id
            elsif vehicle[:spawn_location] == "player_decides"
              vehicle[:chosen_location] = "Nearby"
              vehicle.delete(:territory_id)
            else
              next # Territory is invalid
            end

            # Increase the vehicle count because we're removing one
            if (previous_territory = @territories.find { |t| previous_choice.casecmp?(t.custom_id) || previous_choice.casecmp?(t.territory_id) })
              previous_territory.vehicle_count -= 1
            end

            success = true
          end

          if !success
            await_for_reply
            event.message.react("❌")
            return
          end

          event.message.react("✅")

          await_for_reply
          edit_message(@vehicle_message, vehicle_embed)
        end
      end
    end
  end
end
