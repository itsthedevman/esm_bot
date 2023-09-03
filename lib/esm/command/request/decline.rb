# frozen_string_literal: true

module ESM
  module Command
    module Request
      class Decline < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        # Required: Duh
        argument :uuid, required: true, checked_against: /[0-9a-fA-F]{4}/

        #
        # Configuration
        #

        change_attribute :allowed_in_text_channels, default: false

        command_type :player

        #################################

        def on_execute
          request = current_user.pending_requests.where(uuid_short: arguments.uuid).first
          check_for_request!(request)
          request.respond(false)

          reply(ESM::Embed.build(:success, description: I18n.t("commands.decline.success_message")))
        end

        private

        def check_for_request!(request)
          check_failed!(:invalid_request_id, user: current_user.mention) if request.nil?
        end
      end
    end
  end
end
