# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Reward < ApplicationCommand
        SPAWN_LOCATIONS = ["virtual_garage", "player_decides"].freeze

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
          end

          @vehicles = []
          @nearby_vehicles = []
          @reward_package = {}

          @locations = selected_reward.reward_vehicles
            .group_by { |v| v["spawn_location"] }
            .transform_values(&:size)

          send_request_description
          request_spawn_locations if spawn_locations_needed?

          case build_reward_package
          when :no_reply
            embed = ESM::Embed.new(
              :error,
              description: I18n.t("commands.reward.errors.no_reply", user: current_user.mention)
            )

            reply(embed, to: current_user)

            return
          when :cancel
            embed = ESM::Embed.build(
              :success,
              title: "Cancelled",
              description: "You may re-run the command to start over"
            )

            reply(embed, to: current_user)

            return
          end

          response = call_sqf_function!("ESMs_command_reward", **@reward_package)

          embed = embed_from_message!(response)
          reply(embed, to: current_user)
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

          reply(embed, to: current_user)
        end

        def request_spawn_locations
          @territories = query_exile_database!("reward_territories", uid: current_user.steam_uid)

          if @territories.present?
            @territories.map! do |territory|
              territory[:territory_id] ||= territory["custom_id"]
              territory.to_istruct
            end

            @territories.sort_by!(&:territory_id)
          end

          @vehicles = selected_reward.vehicles
            .reject do |vehicle|
              # They'll be added back later. We don't need a location for them
              @nearby_vehicles << vehicle if vehicle[:spawn_location] == "nearby"
            end

          embed =
            ESM::Embed.new do |e|
              e.title = "Vehicle Configuration"
              e.description = ""
              e.add_field(name: "", value: "```#{spawn_locations_table}```")
              e.add_field(name: "Vehicles", value: "```#{vehicles_table}```")
            end

          reply(embed, to: current_user)
        end

        def spawn_locations_table
          Terminal::Table.new do |t|
            t.style = {
              # width: 63,
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

              t.add_row([
                territory.custom_id || territory.territory_id,
                territory.name.truncate(60),
                free_spots
              ])
            end
          end
        end

        def vehicles_table
          Terminal::Table.new do |t|
            t.style = {
              border: :unicode,
              # width: 63,
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

              t.add_row([
                index + 1,
                vehicle[:chosen_location] || "Choose...",
                display_name
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
          location_data = response_event.message.content.split.map { |s| s.split(":") }

          success = false
          location_data.each do |vehicle_index, location|
            vehicle_index = [vehicle_index.to_i - 1, 0].max
            vehicle = @vehicles[vehicle_index]
            next if vehicle.nil?

            # Check to make sure this territory is valid.
            # The user can use a custom id or territory ID
            location = location.downcase
            territory = @territories.find do |territory|
              location.casecmp?(territory.custom_id) ||
                location.casecmp?(territory.territory_id)
            end

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
            previous_territory = @territories.find do |territory|
              previous_choice.casecmp?(territory.custom_id) ||
                previous_choice.casecmp?(territory.territory_id)
            end

            previous_territory.vehicle_count -= 1 if previous_territory
            success = true
          end

          if !success
            response_event.message.react("❌")
            return :continue
          end

          response_event.message.react("✅")
          edit_message(@vehicle_message, vehicle_embed)

          :continue
        end

        def on_accept
          vehicles = @vehicles + @nearby_vehicles

          if vehicles.present?
            # Check to see if all vehicles have the required information
            invalid_vehicle_numbers = vehicles.map.with_index do |vehicle, index|
              next if vehicle[:territory_id].present? ||
                (vehicle[:chosen_location] || vehicle[:spawn_location]).casecmp?("nearby")

              index + 1
            end.compact

            if invalid_vehicle_numbers.present?
              reply("Yo, you forgot some. #{invalid_vehicle_numbers}", to: current_user)
              return :continue
            end

            vehicles.map! do |vehicle|
              {
                class_name: vehicle[:class_name],
                spawn_location: vehicle[:territory_id] || "nearby"
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

          if vehicles.present?
            @reward_package[:vehicles] = vehicles
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
