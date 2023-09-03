# frozen_string_literal: true

module ESM
  module Command
    module Pictures
      class Meow < ApplicationCommand
        SUB_REDDIT = %w[lolcats catpics catpictures Chonkers CatsStandingUp].freeze

        #################################
        #
        # Configuration
        #

        change_attribute :cooldown_time, modifiable: false, default: 5.seconds

        command_type :player

        does_not_require :registration

        #################################

        def on_execute
          send_waiting_message
          check_for_empty_link!
          remove_waiting_message

          # Send the link
          reply(link)
        end

        private

        def check_for_empty_link!
          return if link.present?

          remove_waiting_message
          check_failed!(:meow_not_found, user: current_user.mention)
        end

        def link
          @link ||= lambda do
            10.times do
              response = begin
                HTTParty.get(
                  "http://www.reddit.com/r/#{SUB_REDDIT.sample}/random.json",
                  headers: {"User-agent": "ESM 2.0"}
                )
              rescue URI::InvalidURIError
                nil
              end

              next sleep(1) unless response&.ok?

              url = response.parsed_response[0]["data"]["children"][0]["data"]["url"]
              next if url.blank?
              next if !url.match(/\.jpg$|\.png$|\.gif$|\.jpeg$/i)

              return url
            end

            nil
          end.call
        end

        def send_waiting_message
          @message = reply(I18n.t("commands.meow.waiting"))
        end

        # Remove the "Waiting..." message
        def remove_waiting_message
          return if ESM.env.test?

          @message.delete
        end
      end
    end
  end
end
