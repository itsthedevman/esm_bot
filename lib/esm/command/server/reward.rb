# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Reward < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        # Optional: Defaults to "default" reward
        argument :reward_id, display_name: :package_name, default: nil

        #
        # Configuration
        #

        command_type :player

        #################################

        def on_execute
          # Check to see if the provided reward_id has anything to redeem
          check_for_reward_items!

          # Check to see if the user is on cooldown for the reward
          check_for_reward_cooldown!

          # Confirm with the player
          confirmed = prompt_for_confirmation!(confirmation_embed)

          nil unless confirmed

          # Add them items to the user's rewards
          # Update their cooldown
          # Let them know!
        end

        private

        def selected_reward
          @selected_reward ||= target_server.server_rewards.find_by(reward_id: arguments.reward_id)
        end

        def reward_cooldown
          # Luckily, the standard command cooldown query basically 90% of the way there
          @reward_cooldown ||=
            current_cooldown_query.rewhere(type: :reward, key: selected_reward.reward_id)
              .first_or_create!
        end

        def check_for_reward_items!
          return if selected_reward.items.size > 0

          raise_error!(:no_reward_items, user: current_user.mention)
        end

        def check_for_reward_cooldown!
          return unless reward_cooldown.active?

          if current_cooldown.cooldown_type == Cooldown::COOLDOWN_TYPE_TIMES
            raise_error!(
              :on_cooldown_useage,
              user: current_user.mention,
              command_name: usage
            )
          end

          raise_error!(
            :on_cooldown_time_left,
            user: current_user.mention,
            time_left: current_cooldown.to_s,
            command_name: usage
          )
        end

        def confirmation_embed
          ESM::Embed.build do |e|
            e.title = translate("confirmation.title")

            expiry =
              if duration
                translate(
                  "expiry.timed",
                  duration: ChronicDuration.output(duration)
                )
              else
                translate("expiry.never")
              end

            e.description = translate(
              "confirmation.description",
              recipient: target_user.discord_mention,
              type: arguments.type.titleize,
              reward_details: translate(
                "reward_details.#{arguments.type}",
                amount: arguments.amount.to_delimitated_s,
                name: display_name
              ),
              expiry:,
              recipient_mention: target_user.discord_mention,
              server_id: target_server.server_id
            )
          end
        end

        ########################################################################

        module V1
          def on_execute
            # Check for pending requests
            check_for_pending_request!

            # Check to see if the server has any rewards for the user before even sending the request
            check_for_reward_items!

            # Add the request
            add_request(
              to: current_user,
              description: I18n.t(
                "commands.reward_v1.request_description",
                user: current_user.mention,
                server: target_server.server_id
              )
            )

            # Remind them to check their PMs
            embed = ESM::Embed.build(
              :success,
              description: I18n.t("commands.request.check_pm", user: current_user.mention)
            )

            reply(embed)
          end

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

          private

          def check_for_reward_items!
            reward = target_server.server_reward

            return if reward.reward_items.present? ||
              reward.locker_poptabs.positive? ||
              reward.player_poptabs.positive? ||
              reward.respect.positive?

            raise_error!(:no_reward_items, user: current_user.mention)
          end
        end
      end
    end
  end
end
