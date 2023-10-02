# frozen_string_literal: true

module ESM
  module Command
    class Base
      module Helpers
        extend ActiveSupport::Concern

        class_methods do
          def usage(opts = {})
            opts[:with_args] ||= false
            new.usage(**opts)
          end
        end

        #
        # Returns the command's execution string, with or without arguments.
        #   /command subcommand argument_1:value argument_2: value
        #
        # @param overrides [Hash] Argument names and values to set.
        #   These will override the default arguments. Ignored if with_args is false
        #
        # @param with_args [true/false] Should the arguments be included in result?
        # @param with_slash [true/false] Should the result start with a slash?
        #
        # @return [String]
        #
        def usage(overrides: {}, with_args: true, with_slash: true)
          command_statement = namespace[:segments].dup
          command_statement << namespace[:command_name]

          if with_args && arguments.size > 0
            arguments.with_templates.each do |(name, data)|
              template = data[:template]

              # Better support for falsey values
              value =
                if overrides.key?(name)
                  overrides[name]
                elsif overrides.key?(template.display_name)
                  overrides[template.display_name]
                else
                  data[:value]
                end

              # Perf
              value_is_blank = value.blank?
              next if value_is_blank && template.optional?

              command_statement << (value_is_blank ? "#{template}:<#{template}>" : "#{template}:#{value}")
            end
          end

          command_statement = command_statement.join(" ")
          command_statement.prepend("/") if with_slash
          command_statement
        end

        #
        # The ESM representation of the user who executed the command
        #
        # @return [ESM::User]
        #
        def current_user
          return @current_user if defined?(@current_user) && !@current_user.nil?
          return if event&.user.nil?

          discord_user = event.user
          user = ESM::User.where(discord_id: discord_user.id).first_or_initialize
          user.update(
            discord_username: discord_user.username,
            discord_avatar: discord_user.avatar_url
          )

          # Save some cycles
          discord_user.instance_variable_set(:@esm_user, user)

          # Return back the modified discord user
          @current_user = user
        end

        #
        # The ESM representation of the Discord server the command was executed on
        #
        # @return [ESM::Community, nil] The community the command was executed from. Nil if sent from Direct Message
        #
        def current_community
          @current_community ||= ESM::Community.find_by(guild_id: event&.server&.id)
        end

        #
        # The cooldown for this command
        #
        # @return [ESM::Cooldown]
        #
        def current_cooldown
          @current_cooldown ||= current_cooldown_query.first
        end

        #
        # The Discord channel this command was executed in
        #
        # @return [Discordrb::Channel]
        #
        def current_channel
          @current_channel ||= event&.channel
        end

        #
        # The ESM representation of a community's Arma 3 Server
        #
        # @return [ESM::Server, nil] The server that the command was executed for
        #
        def target_server
          @target_server ||= ESM::Server.find_by(server_id: arguments.server_id) if arguments.server_id
        end

        #
        # The ESM representation of a Discord server that is the target of this command
        #
        # @return [ESM::Community, nil] The community that the command was executed for
        #
        def target_community
          @target_community ||= begin
            return ESM::Community.find_by(community_id: arguments.community_id) if arguments.community_id

            target_server&.community
          end
        end

        #
        # The ESM representation of a Discord user that is the target of this command
        #
        # @return [ESM::User, nil] The user that the command was executed against
        #
        def target_user
          @target_user ||= begin
            return unless arguments.target&.match?(ESM::Regex::TARGET)

            # This could be a steam_uid, discord id, or mention
            target = arguments.target

            # Attempt to parse first
            user = ESM::User.parse(target)

            # No user was found. Don't create a user from a steam UID
            #   target is a steam_uid WITHOUT a db user. -> Exit early. Use a placeholder user
            if user.nil? && target.steam_uid?
              @target_user = ESM::User::Ephemeral.new(target)
              return
            end

            # Past this point:
            #   target is a steam_uid WITH a db user -> Continue
            #   target is a discord ID or discord mention WITH a db user -> Continue
            #   target is a discord ID or discord mention WITHOUT a db user -> Continue, we'll create a user

            # Remove the tag bits if applicable
            target.gsub!(/[<@!&>]/, "") if ESM::Regex::DISCORD_TAG_ONLY.match(target)

            # Get the discord user from the ID or the previous db entry
            discord_user = user.nil? ? ESM.bot.user(target) : user.discord_user

            # Nothing we can do if we don't have a discord user
            return if discord_user.nil?

            # Create the user if its nil
            user = ESM::User.new(discord_id: target) if user.nil?
            user.update!(discord_username: discord_user.username, discord_avatar: discord_user.avatar_url)

            # Save some cycles
            user.instance_variable_set(:@discord_user, discord_user)
            @target_user = user
          end
        end

        #
        # Sometimes we're given a steam UID that may not be linked to a discord user
        # But, the command can work without the registered part.
        #
        # @return [String, nil] The steam uid from given argument or the steam uid registered to the target_user (which may be nil)
        #
        def target_uid
          return if arguments.target.nil?

          @target_uid ||= lambda do
            arguments.target.steam_uid? ? arguments.target : target_user&.steam_uid
          end.call
        end

        #
        # The community, in which this command is being executed, command permissions
        #
        # @return [ESM::CommandConfiguration, nil]
        #
        def community_permissions
          @community_permissions ||= begin
            community = target_community || current_community
            return unless community

            community.command_configurations.where(command_name: name).first
          end
        end

        #
        # Is the current_user also the target_user?
        #
        # @return [Boolean]
        #
        def same_user?
          return false if target_user.nil?

          current_user.steam_uid == target_user.steam_uid
        end

        #
        # Is the command limited to Direct Messages?
        #
        # @return [Boolean]
        #
        def dm_only?
          limited_to == :dm
        end

        #
        # Is the command limited to text channels?
        #
        # @return [Boolean]
        #
        def text_only?
          limited_to == :text
        end

        #
        # Is the command limited to developers only?
        #
        # @return [Boolean]
        #
        def dev_only?
          requirements.dev?
        end

        #
        # Does the command require registration?
        #
        # @return [Boolean]
        #
        def registration_required?
          requirements.registration?
        end

        #
        # Is this command on cooldown?
        #
        # @return [Boolean]
        #
        def on_cooldown?
          # We've never used this command with these arguments before
          return false if current_cooldown.nil?

          current_cooldown.active?
        end

        #
        # Makes calls to I18n.t shorter
        #
        def t(translation_name, **)
          I18n.t("commands.#{name}.#{translation_name}", **)
        end

        #
        # Returns the commands argument values
        #
        # @return [ESM::Command::ArgumentContainer] The commands arguments
        #
        def args
          @arguments
        end

        #
        # Builds a message and raises a CheckFailure with that reason.
        #
        # @param error_name [String, Symbol, nil] The name of the error message located in the locales for "commands.<command_name>.errors". If nil, a block must be provided
        # @param args [Hash] The args to be passed into the translation if an error_name is provided
        # @param block [Proc] If provided, the block must return the error message to be used. This can be a string or an ESM::Embed.
        #
        def raise_error!(error_name = nil, **args, &block)
          exception_class = args.delete(:exception_class)

          reason =
            if block
              yield
            else
              ESM::Embed.build(:error, description: I18n.t("commands.#{name}.errors.#{error_name}", **args))
            end

          # Logging
          warn!(
            author: "#{current_user.distinct} (#{current_user.discord_id})",
            channel: "#{Discordrb::Channel::TYPE_NAMES[current_channel.type]} (#{current_channel.id})",
            reason: reason.is_a?(Embed) ? reason.description : reason,
            command: to_h
          )

          raise exception_class || ESM::Exception::CheckFailure, reason
        end

        def skip_action(*)
          skipped_actions.set(*)
        end

        #
        # Sends a message to the target_server
        #
        # @param outgoing_message [ESM::Message, Hash] If a ESM::Message is provided, this message will be sent as is. If a Hash is provided, a message will be built from it
        # @param send_opts [Hash] Passed into #send_message. @see ESM::Connection::Server.fire
        # @return [ESM::Message] The message that was sent
        #
        def send_to_arma(outgoing_message = {}, send_opts = {})
          raise ESM::Exception::CheckFailure, "Command #{name} must define the `server_id` argument in order to use #send_to_arma" if target_server.nil?

          # Allows overwriting the outbound message. Otherwise, build a message from the data
          if outgoing_message.is_a?(Hash)
            # Allows providing `data: content` or,
            #                  `data: { type: :different }` or,
            #                  `data: { type: :different, content: different_content }`
            data = outgoing_message[:data] || {}
            unless data.key?(:type) && (data.key?(:content) || data.size == 1)
              outgoing_message[:data] = {
                type: name,
                content: outgoing_message[:data]
              }
            end

            outgoing_message[:type] = :arma unless outgoing_message.key?(:type)
            outgoing_message = ESM::Message.from_hash(outgoing_message)

            # This is how the message gets back to the command
            outgoing_message.add_callback(:on_response, on_instance: self) do |incoming_message|
              timers.time!(:on_response) do
                on_response(incoming_message, outgoing_message)
              end
            end
          end

          outgoing_message.add_attribute(:server_id, target_server.server_id)
          outgoing_message.add_attribute(:command, self)
          outgoing_message.apply_command_metadata

          target_server.send_message(outgoing_message, send_opts)
        end

        #
        # Shorthand method for sending a query message to Arma
        #
        # @param name [String, Symbol] The name of the query
        # @param **arguments [Hash] The query arguments
        #
        # @return [ESM::Message] The outbound message
        #
        def query_arma(name, **arguments)
          send_to_arma(
            type: :query,
            data: {
              type: :query,
              content: {
                name: name,
                arguments: arguments
              }
            }
          )
        end

        # Convenience method for replying back to the event's channel
        def reply(message)
          pending_delivery = ESM.bot.deliver(message, to: current_channel, async: false)
          pending_delivery.wait_for_delivery
        end

        #
        # Replies to a Discordrb::ApplicationCommandEvent using the #respond method
        # Makes it easier to send messages or embeds without needing to handle them
        #
        # @param message [String, ESM::Embed] The message or embed to send
        # @param **flags [Hash] Any other options to send into #respond
        #
        def respond(message, **flags)
          data = flags.deep_dup
          if message.is_a?(ESM::Embed)
            data[:embeds] = [message.for_discord_embed]
          else
            data[:content] = message
          end

          event.respond(**data)
        end

        def edit_message(message, content)
          if content.is_a?(ESM::Embed)
            embed = Discordrb::Webhooks::Embed.new
            content.transfer(embed)

            message.edit("", embed)
          else
            message.edit(content)
          end
        end

        def request
          @request ||= lambda do
            requestee = target_user || current_user

            # Don't look for the requestor because multiple different people could attempt to invite them
            # requestor_user_id: current_user.esm_user.id,
            query = ESM::Request.where(requestee_user_id: requestee.id, command_name: command_name)

            arguments.to_h.each do |name, value|
              query = query.where("command_arguments->>'#{name}' = ?", value)
            end

            query.first
          end.call
        end

        def add_request(to:, description: "")
          @request =
            ESM::Request.create!(
              requestor_user_id: current_user.id,
              requestee_user_id: to.id,
              requested_from_channel_id: current_channel.id.to_s,
              command_name: command_name,
              command_arguments: arguments.to_h
            )

          send_request_message(description: description, target: to)
        end

        def request_url
          # I have no idea why the ENV won't apply for this _one_ key.
          if ESM.env.production?
            "https://www.esmbot.com/requests"
          else
            ENV["REQUEST_URL"]
          end
        end

        def accept_request_url(uuid)
          "#{request_url}/#{uuid}/accept"
        end

        def decline_request_url(uuid)
          "#{request_url}/#{uuid}/decline"
        end

        def send_request_message(target:, description: "")
          embed =
            ESM::Embed.build do |e|
              e.set_author(name: current_user.distinct, icon_url: current_user.avatar_url)
              e.description = description
              e.add_field(name: I18n.t("commands.request.accept_name"), value: I18n.t("commands.request.accept_value", url: accept_request_url(request.uuid)), inline: true)
              e.add_field(name: I18n.t("commands.request.decline_name"), value: I18n.t("commands.request.decline_value", url: decline_request_url(request.uuid)), inline: true)
              e.add_field(name: I18n.t("commands.request.command_usage_name"), value: I18n.t("commands.request.command_usage_value", uuid: request.uuid_short))
            end

          ESM.bot.deliver(embed, to: target)
        end

        def create_or_update_cooldown
          @current_cooldown = current_cooldown_query.first_or_create
          current_cooldown.update_expiry!(timers.on_execute.started_at, cooldown_time)
        end

        def current_cooldown_query
          query = ESM::Cooldown.where(command_name: name)

          # If the command requires a steam_uid, use it to track the cooldown.
          query =
            if registration_required?
              query.where(steam_uid: current_user.steam_uid)
            else
              query.where(user_id: current_user.id)
            end

          # Check for the target_community
          query = query.where(community_id: target_community.id) if target_community

          # If we don't have a target_community, use the current_community (if applicable)
          query = query.where(community_id: current_community.id) if current_community && target_community.nil?

          # Check for the individual server
          query = query.where(server_id: target_server.id) if target_server

          # Return the query
          query
        end
      end
    end
  end
end
