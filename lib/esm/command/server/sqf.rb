# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Sqf < ESM::Command::Base
        v2_variant!

        command_type :admin
        command_namespace :server, :admin, command_name: :execute_code

        limit_to :text
        requires :registration

        change_attribute :whitelist_enabled, default: true

        skip_action :nil_target_user

        argument :server_id, display_name: :on
        argument :target, check_against: /#{ESM::Regex::TARGET.source}|server|all|everyone/i
        argument :code_to_execute, display_name: :code, preserve: true

        def on_execute
          check_owned_server!
          check_registered_target_user! if target_user.is_a?(ESM::User)

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
