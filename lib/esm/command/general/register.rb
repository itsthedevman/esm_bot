# frozen_string_literal: true

module ESM
  module Command
    module General
      class Register < ApplicationCommand
        #################################
        #
        # Configuration
        #

        change_attribute :cooldown_time, modifiable: false
        change_attribute :enabled, modifiable: false
        change_attribute :whitelist_enabled, modifiable: false
        change_attribute :whitelisted_role_ids, modifiable: false

        command_type :player

        use_root_namespace

        #################################

        def on_execute
          message =
            if current_user.registered?
              already_registered_message
            else
              registration_message
            end

          reply(message)
        end

        private

        def already_registered_message
          ESM::Embed.build do |e|
            e.description = I18n.t("commands.register.already_registered", user: current_user.mention)
          end
        end

        def registration_message
          ESM::Embed.build do |e|
            e.description = I18n.t("command_errors.not_registered", user: current_user.mention, full_username: current_user.distinct)
          end
        end
      end
    end
  end
end
