# frozen_string_literal: true

module ESM
  module Command
    module Request
      class Requests < ESM::Command::Base
        command_type :player
        command_namespace :request, command_name: :list

        change_attribute :allowed_in_text_channels, default: false

        def on_execute
          requests = current_user.pending_requests.select(:uuid, :uuid_short, :command_name, :requestor_user_id, :expires_at).order(:command_name)
          return send_no_requests_message if requests.blank?

          embed = ESM::Embed.build do |e|
            e.title = "Pending Requests"

            e.description = requests.map do |r|
              description = "`#{r.command_name}` - "
              description += "#{r.requestor.distinct} - " if current_user.id != r.requestor_user_id # Performance optimization, only query if needed

              description + <<~STRING
                Expires on #{r.expires_at}
                [Accept](#{accept_request_url(r.uuid)}) - `/requests accept uuid:#{r.uuid_short}`
                [Decline](#{decline_request_url(r.uuid)}) - `/requests decline uuid:#{r.uuid_short}`
              STRING
            end.join("\n")
          end

          reply(embed)
        end

        private

        def send_no_requests_message
          reply(ESM::Embed.build(:success, description: "#{current_user.mention}, you do not have any pending requests"))
        end
      end
    end
  end
end
