# frozen_string_literal: true

module ESM
  module Command
    module Territory
      class SetId < ESM::Command::Base
        command_type :player

        requires :registration

        argument :old_territory_id, template: :territory_id, display_name: :from
        argument :new_territory_id, template: :territory_id, display_name: :to
        argument :server_id, display_name: :on

        def on_execute
          # Require at least 3 characters and a max of 30
          check_for_minimum_characters!
          check_for_maximum_characters!

          # Set the request
          deliver!(
            command_name: "setterritoryid",
            query: "set_custom_territory_id",
            player_uid: current_user.steam_uid,
            old_territory_id: arguments.old_territory_id,
            new_territory_id: arguments.new_territory_id
          )
        end

        def on_response(_, _)
          check_for_failure!
          reply(success_message)
        end

        private

        def check_for_minimum_characters!
          return if arguments.new_territory_id.nil?

          check_failed!(:minimum_characters, user: current_user.mention) if arguments.new_territory_id.size < 3
        end

        def check_for_maximum_characters!
          return if arguments.new_territory_id.nil?

          check_failed!(:maximum_characters, user: current_user.mention) if arguments.new_territory_id.size > 20
        end

        def check_for_failure!
          return if @response.success

          # Don't set a cooldown if we errored.
          skip_action(:cooldown)

          # DLL Reason. This is a weird one since I can't localize the message
          check_failed! { ESM::Embed.build(:error, description: "I'm sorry #{current_user.mention}, #{@response.reason}") } if @response.reason

          check_failed!(:access_denied, user: current_user.mention)
        end

        def success_message
          ESM::Embed.build(
            :success,
            description: I18n.t(
              "commands.set_id.success_message",
              prefix: prefix,
              server_id: target_server.server_id,
              old_territory_id: arguments.old_territory_id,
              new_territory_id: arguments.new_territory_id
            )
          )
        end
      end
    end
  end
end