# frozen_string_literal: true

module ESM
  module Command
    module Request
      class Decline < ESM::Command::Base
        command_type :player

        limit_to :dm

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        argument :uuid, regex: /[0-9a-fA-F]{4}/

        def on_execute
          request = current_user.pending_requests.where(uuid_short: @arguments.uuid).first
          check_for_request!(request)
          request.respond(false)

          reply(ESM::Embed.build(:success, description: I18n.t("commands.decline.success_message")))
        end

        #########################
        # Command Methods
        #########################
        def check_for_request!(request)
          check_failed!(:invalid_request_id, user: current_user.mention) if request.nil?
        end
      end
    end
  end
end
