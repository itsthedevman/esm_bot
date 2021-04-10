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
        define :cooldown_time, modifiable: true, default: 1.times

        argument :server_id

        # This is the reward_id. It's basically a server_id
        # Since it shares a similar structure to server_id, we can use server_id's before_store callback to allow auto-filling the community_id
        argument :reward_id, regex: ESM::Regex::REWARD_ID_OPTIONAL_COMMUNITY, template: :server_id, default: nil

        # Skip the main cooldown check. Reward handles cooldowns differently
        skip_check :cooldown

        def discord
          # Check for pending requests
          @checks.pending_request!

          # Check to see if the server has any rewards for the user before even sending the request
          check_for_valid_reward_id!
          check_for_reward_items!

          # Add the request
          # TODO V2: Inform user to run `!territories id` first before accepting the request.
          if target_server.version.nil?
            # V1
            add_request(
              to: current_user,
              # TODO: Add what is included in the reward. For items, just count the vehicles and items out
              description: I18n.t("commands.reward.request_description", user: current_user.mention, server: target_server.server_id)
            )
          else

          end

          # Remind them to check their PMs
          embed = ESM::Embed.build(:success, description: I18n.t("commands.request.check_pm", user: current_user.mention))
          reply(embed)
        end

        def server
          # Array<Array<item, quantity>>
          receipt = @response.receipt.to_h

          embed = ESM::Embed.build(
            :success,
            description: I18n.t(
              "commands.reward.receipt",
              user: current_user.mention,
              items: receipt.format { |item, quantity| "- #{quantity}x #{item}\n" }
            )
          )

          reply(embed)
        end

        def request_accepted
          if target_server.version.nil?
            # V1
            deliver!(function_name: "rewardPlayer", target_uid: current_user.steam_uid)
          else
            @reward_vehicles = reward_package.reward_vehicles

            # Vehicles require gathering the pin code and territory data if the vehicles are to be spawned in the garage
            if @reward_vehicles.present?
              gather_pincode_data
              gather_territory_data if @reward_vehicles.any? { |vehicle| vehicle[:spawn_location] == "virtual_garage" }
            end

            # V2
            send_to_a3(
              target_uid: current_user.steam_uid,
              reward_items: reward_package.reward_items.to_a,
              reward_vehicles: @reward_vehicles,
              locker_poptabs: reward_package.locker_poptabs,
              player_poptabs: reward_package.player_poptabs,
              respect: reward_package.respect
            )
          end
        end

        private

        def reward_package
          @reward_package ||= target_server.server_rewards.where(reward_id: @arguments.reward_id).first
        end

        def check_for_valid_reward_id!
          return if reward_package.present?

          check_failed!(:incorrect_reward_id, user: current_user.mention, reward_id: @arguments.reward_id)
        end

        def check_for_reward_items!
          return if reward_package.reward_items.present? ||
                    reward_package.reward_vehicles.present? ||
                    reward_package.locker_poptabs.positive? ||
                    reward_package.player_poptabs.positive? ||
                    reward_package.respect.positive?

          check_failed!(:no_reward_items, user: current_user.mention)
        end

        def gather_territory_data
          # vg_vehicles = @reward_vehicles.select { |vehicle| vehicle[:spawn_location] == "virtual_garage" }

          # # Build the regex to parse a 4 digit pin code for each vehicle. Each line represents one vehicle.
          # # For example:
          # #   1. Truck
          # #   2. Car
          # #   3. Van
          # #
          # regex = vg_vehicles.format { |_v| "\\d{4}\\s+" }[0..-4]
          # response = ESM.bot.deliver_and_await!(embed, to: current_channel, owner: current_user, expected: [regex], timeout: 120)
          # return reply(I18n.t("commands.broadcast.cancelation_reply")) if response.nil? || response.downcase == I18n.t("no").downcase
        end

        def gather_pincode_data
          # Build the regex to parse a 4 digit pin code for each vehicle. Each line represents one vehicle.
          regex = @reward_vehicles.format { |_v| "\\d{4}\\s+" }[0..-4]

          embed =
            ESM::Embed.build do |e|
              # e.set_author(name:, url: nil, icon_url: nil)
              # e.title=(text)
              # e.description=(text)
              # e.add_field(name: nil, value:, inline: false)
              # e.thumbnail=(url)
              # e.image=(url)
              # e.color=(color)
              # e.footer=(text)
              # e.set_footer(text: nil, icon_url: nil)
              e.title = "Step 1: Pincode "
            end

          response = ESM.bot.deliver_and_await!(embed, to: current_channel, owner: current_user, expected: [regex], timeout: 120)
          return reply(I18n.t("commands.broadcast.cancelation_reply")) if response.nil? || !response.match(regex)

          binding.pry
        end
      end
    end
  end
end
