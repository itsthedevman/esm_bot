# frozen_string_literal: true

module ESM
  module Command
    module Server
      class RewardAdmin < ApplicationCommand
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
          poptab: "Reward poptabs",
          respect: "Reward respect",
          item: "Reward Item",
          vehicle: "Reward Vehicle"
        }

        # Required
        argument :classname,
          required: {discord: false, bot: true},
          checked_against_if: ->(_a, _c) { %w[poptab respect].include?(arguments.type) }

        # Required
        argument :amount,
          :integer,
          required: {discord: false, bot: true},
          checked_against_if: ->(_a, _c) { arguments.type == "vehicle" }

        #
        # Configuration
        #

        command_type :player

        #################################

        def on_execute
        end
      end
    end
  end
end
