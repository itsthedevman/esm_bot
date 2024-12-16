# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Reward < ApplicationCommand
        NEARBY = ServerReward::LOCATION_NEARBY
        VIRTUAL_GARAGE = ServerReward::LOCATION_VIRTUAL_GARAGE
        PLAYER_DECIDES = ServerReward::LOCATION_PLAYER_DECIDES

        SPAWN_LOCATIONS = [VIRTUAL_GARAGE, PLAYER_DECIDES].freeze

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
          @locations = load_vehicle_locations

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
          vehicles = selected_reward.vehicles
          vehicles.each do |vehicle|
            vehicle[:chosen_location] = NEARBY if vehicle[:spawn_location] == NEARBY
          end

          # Alternative to sort_by to avoid dealing with "booleans" and sorting
          nil_locations, present_locations = vehicles.partition { |v| v[:chosen_location].nil? }

          # Put the vehicles that need locations up front
          nil_locations + present_locations
        end

        def load_vehicle_locations
          selected_reward.reward_vehicles
            .group_by { |v| v[:spawn_location] }
            .transform_values(&:size)
        end

        def spawn_locations_needed?
          @spawn_locations_needed ||= SPAWN_LOCATIONS.any? { |location| @locations.key?(location) }
        end

        def send_request_description
          base_path = "commands.reward.information_embed"

          embed = ESM::Embed.new do |e|
            e.color = :green

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
                value: I18n.t("#{locale_path}.value", vehicles:)
              )
            end

            if !spawn_locations_needed?
              e.add_field(value: I18n.t("#{base_path}.fields.accept"))
            end

            e.footer = I18n.t("#{base_path}.footer")
          end

          reply(embed)
        end

        def request_spawn_locations
          @territories = query_exile_database!("reward_territories", uid: current_user.steam_uid)

          if @territories.present?
            max_size_lookup = target_server.metadata.vg_max_sizes.to_a

            @territories.map! do |territory|
              max_size = max_size_lookup[territory[:level]].to_i

              territory[:territory_id] ||= territory["custom_id"]
              territory[:number_of_free_spots] =
                if territory[:vehicle_count] >= max_size
                  -1
                else
                  max_size - territory[:vehicle_count]
                end

              territory.to_istruct
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
          content = <<~STRING.chomp
            ## Vehicle Configuration
            ```#{spawn_locations_table}```
            ## Vehicles
            ```#{vehicles_table}```
          STRING

          content +=
            if @results.blank?
              <<~STRING

                ### Results
                TODO
              STRING
            else
              <<~STRING

                ### Results
                ```#{@results}```
              STRING
            end

          content
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

            t.headings = ["ID", "Name", "Slots left"]

            t.add_row([NEARBY, "Spawn near player", "∞"])
            t.add_separator(border_type: :dash)

            @territories.each do |territory|
              t.add_row([
                territory.custom_id || territory.territory_id,
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

            t.headings = ["Vehicle #", "Location", "Vehicle Name", "Limited To"]

            @vehicles.each_with_index do |vehicle, index|
              display_name = vehicle[:display_name].truncate(80)

              limited_to =
                case vehicle[:spawn_location]
                when VIRTUAL_GARAGE
                  "Virtual Garage"
                when NEARBY
                  "Nearby"
                else
                  ""
                end

              vehicle_id =
                if vehicle[:spawn_location] == NEARBY
                  "╌╌╌"
                else
                  index + 1
                end

              t.add_row([
                vehicle_id,
                vehicle[:chosen_location] || "Choose...",
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
          if !content.match?(/(\d+:\w+)+/i)
            response_event.message.react("❌")
            return :continue
          end

          store_vehicle_location(response_event)
        end

        def store_vehicle_location(response_event)
          # Supports one at a time or multiple
          location_data = response_event.message.content.split.map { |s| s.squish.split(":") }

          results = location_data.to_h { |i, _l| [i.to_i, ""] }

          # valid_vehicle_id:nearby
          # valid_vehicle_id:valid_territory_id
          # valid_vehicle_id:invalid_territory_id
          # locked_vehicle_id:invalid_location
          location_data.each do |provided_index, location|
            location = location.downcase
            provided_index = provided_index.to_i
            vehicle_index = [provided_index - 1, 0].max

            vehicle = @vehicles[vehicle_index]
            if vehicle.nil?
              results[provided_index] = "Not a valid vehicle #"
              next
            end

            # Check to make sure this territory is valid.
            # The user can use a custom id or territory ID
            territory = @territories.find do |territory|
              location.casecmp?(territory.custom_id) ||
                location.casecmp?(territory.territory_id)
            end

            # Block assigning a VG only vehicle to nearby
            if vehicle[:spawn_location] == VIRTUAL_GARAGE && location == NEARBY
              results[provided_index] = "Vehicle is limited to VG, location must be a territory ID"
              next
            end

            # Store the location on the vehicle
            if location == NEARBY
              vehicle[:chosen_location] = NEARBY
              vehicle.delete(:territory_id)
            elsif territory && SPAWN_LOCATIONS.include?(vehicle[:spawn_location])
              territory.number_of_free_spots += 1

              vehicle[:chosen_location] = territory.custom_id || territory.territory_id
              vehicle[:territory_id] = territory.id
            else
              results[provided_index] = "\"#{location}\" is not a valid territory ID"
              next
            end

            previous_choice = vehicle[:chosen_location]

            # Increase the vehicle count if we removed one
            previous_territory = @territories.find do |territory|
              previous_choice.casecmp?(territory.custom_id) ||
                previous_choice.casecmp?(territory.territory_id)
            end

            if previous_territory && previous_territory.number_of_free_spots != -1
              previous_territory.number_of_free_spots -= 1
            end
          end

          @results = results.join_map("\n") do |index, reason|
            reason = reason.presence || "Updated"
            "##{index}: #{reason}"
          end

          edit_message(@vehicle_configuration_message, vehicle_configuration_content)

          :continue
        end

        def on_accept
          if @vehicles.present?
            # Check to see if all vehicles have the required information
            invalid_vehicle_numbers = @vehicles.map.with_index do |vehicle, index|
              next if vehicle[:territory_id].present? ||
                (vehicle[:chosen_location] || vehicle[:spawn_location]).casecmp?(NEARBY)

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
