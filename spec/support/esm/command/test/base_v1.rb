# frozen_string_literal: true

module ESM
  module Command
    module Test
      class BaseV1 < ESM::Command::Base
        ARGUMENT_COUNT = 7

        set_type :player

        requires :registration

        define :enabled, modifiable: true, default: true
        define :whitelist_enabled, modifiable: true, default: false
        define :whitelisted_role_ids, modifiable: true, default: []
        define :allowed_in_text_channels, modifiable: true, default: true
        define :cooldown_time, modifiable: true, default: 2.seconds

        argument :community_id
        argument :server_id
        argument :target
        argument :_integer, regex: /1/, description: "test_base._integer", type: :integer
        argument :_preserve, regex: /preserve/, description: "test_base._preserve", preserve: true
        argument :_display_as, regex: /display_name/, description: "test_base._display_as", display_name: "sa_yalpsid"

        # Leave these at the end
        argument :_default, regex: /default/, description: "test_base._default", default: "not_default"

        def on_execute
          "discord"
        end

        def on_response(_, _)
          raise ESM::Exception::CheckFailure, ESM::Embed.build(:error, description: "This failed a check") if @defines.FLAG_RAISE_ERROR

          "server"
        end

        module ErrorMessage
          def self.some_reason
            "I crashed! HALP!"
          end
        end
      end
    end
  end
end
