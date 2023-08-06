# frozen_string_literal: true

module ESM
  module Command
    module Server
      class Reset < ESM::Command::Base
        command_type :admin
        command_namespace :server, :admin, command_name: :reset_player

        limit_to :text
        requires :registration

        change_attribute :whitelist_enabled, default: true

        argument :target, display_name: :whom
        argument :server_id, display_name: :on

        def on_execute
          check_registered_target_user! if target_user.is_a?(ESM::User)

          # Create a confirmation request to the requestee
          check_pending_request!
          add_request(
            to: current_user,
            description: I18n.t(
              "commands.reset.request_description",
              user: current_user.mention,
              server: target_server.server_id
            )
          )

          # Remind them to check their PMs
          embed = ESM::Embed.build(:success, description: I18n.t("commands.request.check_pm", user: current_user.mention))
          reply(embed)
        end

        def on_response(_, _)
          embed =
            if target_user.present?
              if @response.success
                ESM::Embed.build(:success, description: I18n.t("commands.reset.success_message_target", user: current_user.mention, target: target_user.mention))
              else
                ESM::Embed.build(:error, description: I18n.t("commands.reset.failure_message_target", user: current_user.mention, target: target_user.mention))
              end
            elsif @response.success
              ESM::Embed.build(:success, description: I18n.t("commands.reset.success_message_all", user: current_user.mention))
            else
              ESM::Embed.build(:error, description: I18n.t("commands.reset.failure_message_all", user: current_user.mention))
            end

          reply(embed)
        end

        def request_accepted
          deliver!(
            query: target_user.present? ? "reset_player" : "reset_all",
            targetUID: target_user&.steam_uid
          )
        end
      end
    end
  end
end
