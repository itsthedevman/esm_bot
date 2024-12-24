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
          when VEHICLE, ITEM
            check_for_valid_classname!
          when POPTAB, RESPECT
            arguments.classname = nil
          end

          # Confirm with the player
          confirmed = prompt_for_confirmation!(
            ESM::Embed.build do |e|
              e.title = "Confirmation"
              e.description = "Are you sure you want to continue?"
            end
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

        def check_for_valid_classname!
          is_valid = call_sqf_function_direct!(
            "ESMs_util_config_isValidClassName",
            arguments.classname
          )

          return if is_valid

          raise_error!(
            :invalid_classname,
            classname: arguments.classname,
            server_id: target_server.server_id
          )
        end
      end
    end
  end
end
