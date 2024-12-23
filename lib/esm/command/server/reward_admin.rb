# frozen_string_literal: true

module ESM
  module Command
    module Server
      class RewardAdmin < ApplicationCommand
        POPTAB = "poptab"
        RESPECT = "respect"
        ITEM = "item"
        VEHICLE = "vehicle"

        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::TEMPLATES[:target]
        argument :target, display_name: :whom

        # See Argument::TEMPLATES[:server_id]
        argument :server_id, display_name: :on

        # Required
        argument :type, required: true, choices: {
          POPTAB => "Poptabs",
          RESPECT => "Respect",
          ITEM => "Item",
          VEHICLE => "Vehicle"
        }

        # Required for items and vehicles - ignored for poptabs, and respect
        argument :classname,
          preserve_case: true,
          required: {discord: false, bot: true},
          checked_against_if: ->(_a, _c) { [ITEM, VEHICLE].include?(arguments.type) }

        # Required for all, but vehicle
        argument :amount,
          :integer,
          required: {discord: false, bot: true},
          default: 0,
          checked_against: Regex::POSITIVE_NUMBER,
          checked_against_if: ->(_a, _c) { arguments.type != VEHICLE }

        #
        # Configuration
        #

        command_namespace :server, :admin, command_name: :reward

        command_type :player

        #################################

        def on_execute
          check_for_registered_target_user! if target_user.is_a?(ESM::User)

          # Handle amount
          case arguments.type
          when POPTAB, RESPECT, ITEM
            check_for_amount!
          else
            arguments.amount = nil
          end

          # Handle classname
          case arguments.type
          when POPTAB, RESPECT
            arguments.classname = nil
          end

          # TODO: Add a3 class lookup check
          # If the class doesn't exist, add warning to confirmation

          # Confirm with the player
          confirmed = prompt_for_confirmation!(
            ESM::Embed.build do |e|
              e.title = "Confirmation"
              e.description = "Are you sure?"
            end,
            timeout: 5.seconds
          )

          return unless confirmed

          # Update the server
          run_database_query!(
            "reward_create",
            uid: target_user.steam_uid,
            **arguments.slice(:type, :classname, :amount)
          )

          # Respond
        end

        private

        def check_for_amount!
          raise_error!(:missing_amount) unless arguments.amount.positive?
        end
      end
    end
  end
end
