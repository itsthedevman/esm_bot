# frozen_string_literal: true

module ESM
  module Command
    module Request
      class Accept < ApplicationCommand
        command_type :player

        change_attribute :allowed_in_text_channels, default: false

        argument :uuid, regex: /[0-9a-fA-F]{4}/

        def on_execute
          request = current_user.pending_requests.where(uuid_short: arguments.uuid).first
          check_for_request!(request)
          request.respond(true)
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
