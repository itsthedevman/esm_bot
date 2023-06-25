# frozen_string_literal: true

module ESM
  module Command
    module Development
      class Eval < ESM::Command::Base
        set_type :development
        requires :dev

        define :enabled, modifiable: false, default: true
        define :whitelist_enabled, modifiable: false, default: false
        define :whitelisted_role_ids, modifiable: false, default: []
        define :allowed_in_text_channels, modifiable: false, default: true
        define :cooldown_time, modifiable: false, default: 2.seconds

        argument :code, regex: /.*/, preserve: true, description: "Code to execute"

        def on_execute
          code = arguments.code
          return binding.pry if code == "bd" && ESM.env.development? # standard:disable Lint/Debugger

          response = eval @arguments.code # rubocop:disable Security/Eval
          reply("Input:\n```ruby\n#{@arguments.code}\n```\nOutput:\n```ruby\n#{response}\n```")
        rescue => e
          reply("An error occurred: ```#{e.message}```Backtrace: ```#{e.backtrace[0..2].join("\n")}```")
        end
      end
    end
  end
end
