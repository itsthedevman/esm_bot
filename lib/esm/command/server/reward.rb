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

        #
        # Configuration
        #

        command_type :player

        # Don't allow adjusting this cooldown. Each reward has it's own cooldown
        change_attribute :cooldown_time, modifiable: false, default: 2.seconds

        #################################

        def on_execute
          check_for_valid_reward_id!
          check_for_reward_items!
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

        ##################################################################

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
