# frozen_string_literal: true

# New command? Make sure to create a migration to add the configuration to all communities
module ESM
  module Command
    module Server
      class Sqf < ESM::Command::Base
        type :admin
        aliases :exec, :execute
        limit_to :text
        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: true
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :server_id
        argument :target, description: "commands.sqf.arguments.execution_target", default: nil, display_as: :execution_target
        argument :code_to_execute, regex: /[\s\S]+/, description: "commands.sqf.arguments.code_to_execute", preserve: true, multiline: true

        def on_execute
          @checks.owned_server!
          @checks.registered_target_user! if target_user.is_a?(Discordrb::User)

          execute_on =
            case args.target
            when "all", "everyone"
              "all"
            when ->(_type) { target_user }
              "player"
            else
              "server"
            end

          send_to_arma(data: { execute_on: execute_on, code: minify_sqf(args.code_to_execute) })
        end

        def on_response(incoming_message, outgoing_message)
          executed_on = outgoing_message.data.execute_on
          data = incoming_message.data

          translation_name = "responses.#{executed_on}"
          translation_name += "_with_result" if data.result.present?

          embed = ESM::Embed.build(
            :success,
            description: t(
              translation_name,
              user: current_user.mention,
              result: data.result,
              result_type: ESM::Arma::ClassLookup.data_type(data.result),
              server_id: target_server.server_id
            )
          )

          reply(embed)
        end

        private

        def minify_sqf(sqf)
          [
            [/\s*\;\s*/, ";"], [/\s*\:\s*/, ":"], [/\s*\,\s*/, ","], [/\s*\[\s*/, "["],
            [/\s*\]\s*/, "]"], [/\s*\(\s*/, "("], [/\s*\)\s*/, ")"], [/\s*\-\s*/, "-"],
            [/\s*\+\s*/, "+"], [/\s*\/\s*/, "/"], [/\s*\*\s*/, "*"], [/\s*\%\s*/, "%"],
            [/\s*\=\s*/, "="], [/\s*\!\s*/, "!"], [/\s*\>\s*/, ">"], [/\s*\<\s*/, "<"],
            [/\s*>>\s*/, ">>"], [/\s*\&\&\s*/, "&&"], [/\s*\|\|\s*/, "||"], [/\s*\}\s*/, "}"],
            [/\s*\{\s*/, "{"], [/\s+/, " "], [/\n+/, ""], [/\r+/, ""], [/\t+/, ""]
          ].each do |group|
            sqf = sqf.gsub(group.first, group.second)
          end

          sqf
        end
      end
    end
  end
end
