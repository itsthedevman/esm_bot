# frozen_string_literal: true

module ESM
  module Event
    #
    # Delegator over Discordrb::Events::ApplicationCommandEvent
    #
    class ApplicationCommand < SimpleDelegator
      #
      # Discordrb's ApplicationCommandEvent code does not appear to handle if there is no server_id and crashes
      #
      def server
        return if server_id.nil?

        __getobj__.server
      end
    end
  end
end
