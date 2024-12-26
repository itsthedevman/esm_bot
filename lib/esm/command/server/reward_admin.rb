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

        # Required for all
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

        # Optional: Defaults to server settings
        argument :expires_after, default: "never"

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
            # TODO: Is there a need to separate vehicles/items at this level?
            # If I keep them separate, I need to add a cfgVehicle check here
            # Otherwise, I can handle item/vehicle detection on the A3 side
            check_for_valid_classname!

            display_name = ESM::Arma::ClassLookup.find(arguments.classname)&.display_name ||
              arguments.classname
          when POPTAB, RESPECT
            arguments.classname = nil
          end

          # Calculate expiry
          if !arguments.expires_after.casecmp?("never")
            duration = ChronicDuration.parse(arguments.expires_after)
            check_for_valid_duration!(duration)

            expires_at = Time.current + duration
          end

          # Confirm with the player
          confirmed = prompt_for_confirmation!(
            confirmation_embed(display_name, expires_at)
          )

          return unless confirmed

          # Update the server
          run_database_query!(
            "reward_create",
            uid: target_user.steam_uid,
            expires_at:,
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

        def check_for_valid_duration!(duration)
          raise_error!(:invalid_expires_after, provided: arguments.expires_after) if duration.nil?
        end

        def confirmation_embed(display_name, expires_at)
          ESM::Embed.build do |e|
            e.title = translate("confirmation.title")

            amount =
              if arguments.type == POPTAB
                arguments.amount.to_delimitated_s
              else
                arguments.amount
              end

            expiry =
              if expires_at
                translate(
                  "confirmation.expiry.timed",
                  duration: ESM::Time.distance_of_time_in_words(expires_at)
                )
              else
                translate("confirmation.expiry.never")
              end

            e.description = translate(
              "confirmation.content",
              recipient: target_user.discord_mention,
              type: arguments.type.titleize,
              reward_details: translate(
                "confirmation.reward_details.#{arguments.type}",
                amount:,
                name: display_name
              ),
              expiry:,
              recipient_mention: target_user.discord_mention,
              server_id: target_server.server_id
            )
          end
        end
      end
    end
  end
end
