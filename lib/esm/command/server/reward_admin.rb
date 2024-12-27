# frozen_string_literal: true

module ESM
  module Command
    module Server
      class RewardAdmin < ApplicationCommand
        POPTAB = "poptabs"
        RESPECT = "respect"
        CLASSNAME = "classname"

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
          CLASSNAME => "Item/Vehicle"
        }

        # Required for items and vehicles - ignored for poptabs, and respect
        argument :classname,
          preserve_case: true,
          required: {discord: false, bot: true},
          checked_against_if: ->(_a, _c) { arguments.type == CLASSNAME }

        # Technically required except for a subset of CLASSNAME entries.
        argument :amount, :integer,
          default: 1,
          checked_against: Regex::POSITIVE_NUMBER

        # Optional: Defaults to server settings
        argument :expires_in, default: "never"

        #
        # Configuration
        #

        command_namespace :server, :admin, command_name: :reward

        command_type :player

        #################################

        def on_execute
          check_for_registered_target_user! if target_user.is_a?(ESM::User)

          # I originally had checks to block amount from being set for vehicles.
          # With items/vehicles being one, it doesn't matter anymore
          check_for_amount!

          if arguments.type == CLASSNAME
            check_for_valid_classname!

            display_name = ESM::Arma::ClassLookup.find(arguments.classname)&.display_name
            display_name ||= arguments.classname
          else
            arguments.classname = nil
          end

          # Calculate expiry
          if !arguments.expires_in.casecmp?("never")
            duration = ChronicDuration.parse(arguments.expires_in)
            check_for_valid_duration!(duration)

            expires_at = Time.current + duration
          end

          # Confirm with the player
          confirmed = prompt_for_confirmation!(
            confirmation_embed(display_name, duration)
          )

          return unless confirmed

          # Update the server
          run_database_query!(
            "add_reward",
            uid: target_user.steam_uid,
            expires_at:,
            source: "command_reward_admin",
            **arguments.slice(:type, :classname, :amount)
          )

          # Respond
          embed = ESM::Embed.build(:success, description: translate("success"))
          reply(embed)
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
          raise_error!(:invalid_expires_in, expires_in: arguments.expires_in) if duration.nil?
        end

        def confirmation_embed(display_name, duration)
          ESM::Embed.build do |e|
            e.title = translate("confirmation.title")

            amount =
              if arguments.type == POPTAB
                arguments.amount.to_delimitated_s
              else
                arguments.amount
              end

            expiry =
              if duration
                translate(
                  "confirmation.expiry.timed",
                  duration: ChronicDuration.output(duration)
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
