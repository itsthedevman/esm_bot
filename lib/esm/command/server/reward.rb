# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Reward < ApplicationCommand
        NEARBY = "nearby"
        VIRTUAL_GARAGE = "virtual_garage"

        LocationFailure = Data.define(:reason)
        LocationSuccess = Data.define(:location)

        Territory = Struct.new(:territory_id, :name, :number_of_free_spots)
        Vehicle = Struct.new(:id, :class_name, :display_name, :limited_to, :spawn_location)

        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        argument :reward_id, display_name: :reward_package, checked_against: ESM::Regex::REWARD_ID

        #
        # Configuration
        #

        command_type :player

        # Don't allow adjusting this cooldown. Each reward has it's own cooldown
        change_attribute :cooldown_time, modifiable: false, default: 2.seconds

        # override :current_channel, :current_user ?

        # FOR DEV ONLY
        skip_action :cooldown, :connected_server

        #################################

        def on_execute
          # Check to see if the server has any rewards for the user before even sending the request
          check_for_valid_reward_id!
          check_for_reward_items!

          # Notify the user that we're sending them a direct message
          # only if the command was from a text channel
          if current_channel.text?
            embed = ESM::Embed.new(
              :success,
              description: I18n.t("commands.reward.errors.check_pm", user: current_user.mention)
            )

            reply(embed)

            # Overwrite the current channel so errors are properly sent to the correct channel
            @current_channel = current_user.discord_user.pm
          end

          @reward_package = {}
          @vehicles = load_reward_vehicles

          send_request_description
          request_spawn_locations if spawn_locations_needed?

          case build_reward_package
          when :no_reply
            embed = ESM::Embed.new(
              :error,
              description: I18n.t("commands.reward.errors.no_reply", user: current_user.mention)
            )

            reply(embed)

            return
          when :cancel
            embed = ESM::Embed.build(
              :success,
              title: "Cancelled",
              description: "You may re-run the command to start over"
            )

            reply(embed)

            return
          end

          response = call_sqf_function!("ESMs_command_reward", **@reward_package)

          embed = embed_from_message!(response)
          reply(embed)
        end

        private

        def check_for_valid_reward_id!
          return if selected_reward.present?

          raise_error!(
            :incorrect_reward_id,
            user: current_user.mention,
            reward_id: arguments.reward_id
          )
        end

        def check_for_reward_items!
          return if selected_reward.reward_items.present? ||
            selected_reward.reward_vehicles.present? ||
            selected_reward.locker_poptabs.positive? ||
            selected_reward.player_poptabs.positive? ||
            selected_reward.respect.positive?

          raise_error!(:no_reward_items, user: current_user.mention)
        end

        def selected_reward
          @selected_reward ||= target_server.server_rewards.find_by(reward_id: arguments.reward_id)
        end

        def load_reward_vehicles
          sort_order = [nil, VIRTUAL_GARAGE, NEARBY]
          vehicles = selected_reward.vehicles
            .sort_by { |v| sort_order.index(v[:limited_to]) }

          vehicles.map.with_index do |vehicle, index|
            vehicle[:id] = index + 1
            vehicle[:spawn_location] = LocationSuccess[NEARBY] if vehicle[:limited_to] == NEARBY

            Vehicle.new(**vehicle)
          end
        end

        def spawn_locations_needed?
          @spawn_locations_needed ||= @vehicles.any? do |vehicle|
            vehicle.limited_to.nil? || vehicle.limited_to == VIRTUAL_GARAGE
          end
        end

        def send_request_description
          base_path = "commands.reward.information_embed"

          embed = ESM::Embed.new do |e|
            e.description = I18n.t(
              "#{base_path}.description",
              user: current_user.mention,
              server_id: target_server.server_id,
              reward_id: selected_reward.reward_id || "default"
            )

            if selected_reward.player_poptabs.positive?
              locale_path = "#{base_path}.fields.player_poptabs"
              poptabs = selected_reward.player_poptabs.to_poptab

              e.add_field(
                name: I18n.t("#{locale_path}.name"),
                value: I18n.t("#{locale_path}.value", poptabs:),
                inline: true
              )
            end

            if selected_reward.locker_poptabs.positive?
              locale_path = "#{base_path}.fields.locker_poptabs"
              poptabs = selected_reward.locker_poptabs.to_poptab

              e.add_field(
                name: I18n.t("#{locale_path}.name"),
                value: I18n.t("#{locale_path}.value", poptabs:),
                inline: true
              )
            end

            if selected_reward.respect.positive?
              locale_path = "#{base_path}.fields.respect"
              respect = selected_reward.respect

              e.add_field(
                name: I18n.t("#{locale_path}.name"),
                value: I18n.t("#{locale_path}.value", respect:),
                inline: true
              )
            end

            if selected_reward.reward_items.present?
              locale_path = "#{base_path}.fields.items"

              items = selected_reward.items
                .sort_by { |v| v[:display_name].downcase }
                .join_map("\n") do |item|
                  "#{item[:quantity]}x #{item[:display_name]}"
                end

              e.add_field(
                name: I18n.t("#{locale_path}.name"),
                value: I18n.t("#{locale_path}.value", items:)
              )
            end

            if selected_reward.reward_vehicles.present?
              locale_path = "#{base_path}.fields.vehicles"

              vehicles = selected_reward.vehicles
                .sort_by { |v| v[:display_name].downcase }
                .join_map("\n") do |vehicle|
                  vehicle[:display_name].to_s
                end

              e.add_field(
                name: I18n.t("#{locale_path}.name"),
                value: I18n.t("#{locale_path}.value", vehicles:),
                inline: true
              )
            end

            if !spawn_locations_needed?
              e.add_field(value: I18n.t("#{base_path}.fields.accept"))
              e.footer = I18n.t("#{base_path}.footer")
            end
          end

          reply(embed)
        end

        def request_spawn_locations
          @territories = query_exile_database!("reward_territories", uid: current_user.steam_uid)

          if @territories.present?
            max_size_lookup = target_server.metadata.vg_max_sizes.to_a

            @territories.map! do |territory|
              max_size = max_size_lookup[territory[:level]].to_i

              territory[:territory_id] = territory[:custom_id].presence || territory[:id]
              territory[:number_of_free_spots] =
                if territory[:vehicle_count] >= max_size
                  -1
                else
                  max_size - territory[:vehicle_count]
                end

              Territory.new(**territory.slice(:territory_id, :name, :number_of_free_spots))
            end

            @territories.sort_by! do |territory|
              [
                territory.territory_id,
                -territory.number_of_free_spots
              ]
            end
          end

          @vehicle_configuration_message = reply(vehicle_configuration_content)
        end

        def vehicle_configuration_content
          status = @vehicles.join_map("\n") do |vehicle|
            spawn_location = vehicle.spawn_location
            case spawn_location
            in LocationSuccess[location:]
              "✅ Vehicle ##{vehicle.id}: " +
                if location.is_a?(Territory)
                  "Set to spawn at #{location.name}"
                else
                  "Set to spawn nearby"
                end
            in LocationFailure[reason:]
              "❌ Vehicle ##{vehicle.id}: #{reason}"
            else
              "⏳ Vehicle ##{vehicle.id}: Not yet assigned"
            end
          end

          territory_id = @territories.sample.territory_id

          <<~STRING.chomp
            ## 📍 Spawn Locations
            Assign vehicles to locations below. Enter one or more choices like `1:nearby` or `1:#{territory_id} 2:nearby`.
            Type `accept` when done or `cancel` to quit.
            ```#{spawn_locations_table}```
            ## 🚗 Vehicle Assignments
            Note: Virtual Garage vehicles cannot spawn nearby. Nearby Only vehicles cannot be changed.
            ```#{vehicles_table}```
            ```#{status}```
          STRING
        end

        def spawn_locations_table
          Terminal::Table.new do |t|
            t.style = {
              border: :unicode,
              border_top: false,
              border_right: false,
              border_bottom: false,
              border_left: false
            }

            t.headings = ["Location ID", "Name", "Slots left"]

            t.add_row([NEARBY, "Spawn near player", "∞"])
            t.add_separator(border_type: :dash)

            @territories.each do |territory|
              t.add_row([
                territory.territory_id,
                territory.name.truncate(60),
                territory.number_of_free_spots
              ])
            end
          end
        end

        def vehicles_table
          Terminal::Table.new do |t|
            t.style = {
              border: :unicode,
              border_top: false,
              border_right: false,
              border_bottom: false,
              border_left: false
            }

            t.headings = ["Vehicle #", "Vehicle Name", "Limited To"]

            @vehicles.each do |vehicle|
              display_name = vehicle.display_name.truncate(80)

              limited_to =
                case vehicle.limited_to
                when VIRTUAL_GARAGE
                  "Virtual Garage"
                when NEARBY
                  "Nearby Only"
                else
                  ""
                end

              vehicle_id =
                if vehicle.limited_to == NEARBY
                  "╌╌╌"
                else
                  vehicle.id
                end

              t.add_row([
                vehicle_id,
                display_name,
                limited_to
              ])
            end
          end
        end

        def build_reward_package
          loop do
            result = handle_user_response
            break result unless result == :continue
          end
        end

        def handle_user_response
          response_event = ESM.bot.add_await!(
            Discordrb::Events::MessageEvent,
            timeout: 5.minutes
          )

          return :no_reply if response_event.nil?

          content = response_event.message.content.squish
          return :cancel if %w[quit exit stop cancel reject].include?(content.downcase)
          return on_accept if %w[done finish accept].include?(content.downcase)

          # The user didn't cancel or accept, and with no vehicles, just loop
          return :continue if @vehicles.blank?

          # Ensure the message is formatted correctly for the vehicle storage
          return :continue if !content.match?(/(\d+:\w+)+/i)

          store_vehicle_location(response_event)
        end

        def store_vehicle_location(response_event)
          # Supports one at a time or multiple
          location_data = response_event.message
            .content
            .split
            .map { |s| s.squish.split(":") }
            .to_h { |id, location| [id.to_i, location] }

          @vehicles.each do |vehicle|
            spawn_location = location_data[vehicle.id]
            next if spawn_location.blank?

            # There's nothing the user can do
            next if vehicle.limited_to == NEARBY

            # Block assigning a VG only vehicle to nearby
            if vehicle.limited_to == VIRTUAL_GARAGE && spawn_location == NEARBY
              vehicle.spawn_location = LocationFailure[
                "Invalid location (nearby not allowed for Virtual Garage vehicles)"
              ]

              next
            end

            previous_location = vehicle.spawn_location&.location

            # Store the location on the vehicle
            if spawn_location == NEARBY
              vehicle.spawn_location = LocationSuccess[NEARBY]
            else
              # The user can use a custom id or territory ID
              territory = @territories.find do |territory|
                spawn_location.casecmp?(territory.territory_id)
              end

              if territory.nil?
                vehicle.spawn_location = LocationFailure[
                  "\"#{spawn_location}\" is not a valid territory ID"
                ]

                next
              end

              vehicle.spawn_location = LocationSuccess[territory]

              # We took up a spot
              territory.number_of_free_spots -= 1
            end

            # If the previous location was a territory, we need to add back a free spot
            if previous_location && previous_location != NEARBY
              previous_territory = @territories.find do |territory|
                previous_location.casecmp?(territory.territory_id)
              end

              # -1 free spots means "unlimited"
              if previous_territory && previous_territory.number_of_free_spots != -1
                previous_territory.number_of_free_spots += 1
              end
            end
          end

          edit_message(@vehicle_configuration_message, vehicle_configuration_content)

          :continue
        end

        def on_accept
          if @vehicles.present?
            # Check to see if all vehicles have the required information
            invalid_vehicle_numbers = @vehicles.map.with_index do |vehicle, index|
              next if vehicle[:territory_id].present? ||
                (vehicle[:spawn_location]).casecmp?(NEARBY)

              index + 1
            end.compact

            if invalid_vehicle_numbers.present?
              reply("Yo, you forgot some. #{invalid_vehicle_numbers}")
              return :continue
            end

            @vehicles.map! do |vehicle|
              {
                class_name: vehicle[:class_name],
                spawn_location: vehicle[:territory_id] || NEARBY
              }
            end
          end

          if (poptabs = selected_reward.player_poptabs) && poptabs.positive?
            @reward_package[:player_poptabs] = poptabs
          end

          if (poptabs = selected_reward.locker_poptabs) && poptabs.positive?
            @reward_package[:locker_poptabs] = poptabs
          end

          if (score = selected_reward.respect) && score.positive?
            @reward_package[:respect] = score
          end

          if (items = selected_reward.reward_items) && items.present?
            @reward_package[:items] = items
          end

          if @vehicles.present?
            @reward_package[:vehicles] = @vehicles
          end
        end

        ########################################################################

        module V1
          def on_response
            # Array<Array<item, quantity>>
            receipt = @response.receipt.to_h

            embed = ESM::Embed.build(
              :success,
              description: I18n.t(
                "commands.reward_v1.receipt",
                user: current_user.mention,
                items: receipt.join_map { |item, quantity| "- #{quantity}x #{item}\n" }
              )
            )

            reply(embed)
          end

          def on_request_accepted
            deliver!(command_name: "reward", function_name: "rewardPlayer", target_uid: current_user.steam_uid)
          end
        end
      end
    end
  end
end
