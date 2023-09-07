# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Sqf < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # See Argument::DEFAULTS[:server_id]
        argument :server_id, display_name: :on

        # Required: Needed by command
        argument :target, required: true, checked_against: /#{ESM::Regex::TARGET.source}|server|all|everyone/i

        # Required: Needed by command
        argument :code_to_execute, display_name: :code, required: true, preserve: true

        #
        # Configuration
        #

        change_attribute :allowlist_enabled, default: true

        command_namespace :server, :admin, command_name: :execute_code
        command_type :admin

        limit_to :text

        # Argument 'target' will trigger this check, but not all values are 'target' values
        skip_action :nil_target_user

        v2_variant!

        ################################

        def on_execute
          check_for_owned_server!
          check_for_registered_target_user! if target_user.is_a?(ESM::User)

          execute_on =
            case args.target
            when "all", "everyone"
              "all"
            when ->(_type) { target_user }
              "player"
            else
              "server"
            end

          send_to_arma(
            data: {execute_on: execute_on, code: args.code_to_execute}
          )
        end

        def on_response(incoming_message, outgoing_message)
          executed_on = outgoing_message.data.execute_on
          data = incoming_message.data

          translation_name = "responses.#{executed_on}"
          translation_name += "_with_result" if !data.result.nil?

          embed = ESM::Embed.build(
            :success,
            description: t(
              translation_name,
              user: current_user.mention,
              target_uid: target_uid,
              result: data.result,
              server_id: target_server.server_id
            )
          )

          reply(embed)
        end
      end
    end
  end
end
