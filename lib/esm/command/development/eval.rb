# frozen_string_literal: true

module ESM
  module Command
    module Development
      class Eval < ApplicationCommand
        #################################
        #
        # Arguments (required first, then order matters)
        #

        argument :code, required: true, preserve: true, description: "Code to execute"

        #
        # Configuration
        #

        change_attribute :allowed_in_text_channels, modifiable: false
        change_attribute :cooldown_time, modifiable: false
        change_attribute :enabled, modifiable: false
        change_attribute :allowlist_enabled, modifiable: false
        change_attribute :allowlisted_role_ids, modifiable: false

        command_type :development

        does_not_require :registration

        requires :dev

        use_root_namespace

        #################################

        def on_execute
          code = arguments.code
          return binding.pry if code == "bd" && ESM.env.development? # standard:disable Lint/Debugger

          response = eval arguments.code # rubocop:disable Security/Eval
          reply("Input:\n```ruby\n#{arguments.code}\n```\nOutput:\n```ruby\n#{response}\n```")
        rescue => e
          reply("An error occurred: ```#{e.message}```Backtrace: ```#{e.backtrace[0..2].join("\n")}```")
        end
      end
    end
  end
end
