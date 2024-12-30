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
          return unless confirmed

          # Add them items to the user's rewards
          run_database_query!(
            "add_rewards",
            uid: current_user.steam_uid,
            items: []
          )

          # Update their cooldown

          # Log event to discord
          # if target_server.server_setting.logging_reward_admin?
          #   embed = admin_embed(display_name, duration)
          #   current_community.send_to_logging_channel(embed)
          # end

          # Respond
          # embed = ESM::Embed.build(:success, description: translate("success"))
          # reply(embed)
        end

        private

        def selected_reward
          @selected_reward ||= target_server.server_rewards.find_by(reward_id: arguments.reward_id)
        end

        def reward_cooldown
          # Luckily, the standard command cooldown query basically 90% of the way there
          @reward_cooldown ||=
            current_cooldown_query.rewhere(
              type: :reward,
              key: selected_reward.reward_id || "default"
            ).first_or_create!
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

            e.description = translate(
              "confirmation.description",
              server_id: target_server.server_id,
              reward_items: format_reward_items
            )
          end
        end

        def format_reward_items
          items = selected_reward.items.sort_by { |i| ServerRewardItem::TYPES.index(i.reward_type) }

          items.join_map("\n") do |item|
            expiry =
              if item.expiry_unit == ServerRewardItem::NEVER
                translate("expiry.never")
              else
                translate("expiry.timed", duration: "#{item.expiry_value} #{item.expiry_unit}")
              end

            case item.reward_type
            when ServerRewardItem::POPTABS
              translate(
                "reward_items.poptabs",
                amount: item.amount.to_delimitated_s,
                expiry:
              )
            when ServerRewardItem::RESPECT
              translate(
                "reward_items.respect",
                amount: item.amount.to_delimitated_s,
                expiry:
              )
            when ServerRewardItem::CLASSNAME
              locale_name =
                if item.amount == 1
                  "reward_items.classname"
                else
                  "reward_items.classname_with_amount"
                end

              translate(
                locale_name,
                name: item.display_name,
                amount: item.amount.to_delimitated_s,
                expiry:
              )
            end
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
