# frozen_string_literal: true

module ESM
  module Command
    module Development
      class Say < ESM::Command::Base
        command_type :development

        requires :dev

        change_attribute :enabled, modifiable: false
        change_attribute :whitelist_enabled, modifiable: false
        change_attribute :whitelisted_role_ids, modifiable: false
        change_attribute :allowed_in_text_channels, modifiable: false
        change_attribute :cooldown_time, modifiable: false

        argument :text, preserve: true, description: "Text to make the bot say"

        def on_execute
          @event.message.delete if !ESM.env.test?
          reply(arguments.text)
        end
      end
    end
  end
end
