# frozen_string_literal: true

# The main driver for all of ESM's commands. This class is synomysis with ActiveRecord::Base in that all commands inherit
# from this class and this class gives access to a lot of the core functionality.
module ESM
  module Command
    class Base
      # Request related methods
      include Request

      class << self
        attr_reader :defines, :command_type, :category, :command_aliases
      end

      def self.name
        return @command_name if !@command_name.nil?

        super
      end

      def self.inherited(child_class)
        child_class.reset_variables!
        super
      end

      def self.reset_variables!
        @command_aliases = []
        @arguments = []
        @type = nil
        @limit_to = nil
        @defines = OpenStruct.new
        @requires = []
        @skipped_checks = Set.new

        # ESM::Command::System::Accept => system
        @category = self.module_parent.name.demodulize.downcase

        # ESM::Command::Server::SetId => set_id
        @command_name = self.name.demodulize.underscore.downcase
      end

      def self.argument(name, opts = {})
        @arguments << [name, opts]
      end

      def self.example(prefix = ESM.config.prefix)
        I18n.t("commands.#{@command_name}.example", prefix: prefix, default: "")
      end

      def self.description(prefix = ESM.config.prefix)
        I18n.t("commands.#{@command_name}.description", prefix: prefix, default: "")
      end

      # I wanted these as methods instead of attributes
      def self.aliases(*aliases)
        @command_aliases = aliases
      end

      def self.type(type)
        @command_type = type
      end

      def self.limit_to(channel_type)
        @limit_to = channel_type
      end

      def self.define(attribute, **opts)
        @defines[attribute] = OpenStruct.new(opts)
      end

      def self.requires(*keys)
        @requires = keys
      end

      def self.attributes
        @attributes ||=
          OpenStruct.new(
            name: @command_name,
            category: @category,
            aliases: @command_aliases,
            arguments: @arguments,
            type: @command_type,
            limit_to: @limit_to,
            defines: @defines,
            requires: @requires,
            skipped_checks: @skipped_checks
          )
      end

      def self.skip_check(*checks)
        checks.each do |check|
          @skipped_checks << check
        end
      end

      #########################
      # Public Instance Methods
      #########################
      attr_reader :name, :category, :type, :aliases, :limit_to,
                  :requires, :executed_at, :response, :cooldown_time,
                  :defines, :permissions, :checks

      attr_writer :current_community

      attr_accessor :event, :arguments

      def initialize
        attributes = self.class.attributes

        # V1 support
        @name = attributes.name.gsub("_v1", "")
        @category = attributes.category
        @aliases = attributes.aliases
        @arguments = ESM::Command::ArgumentContainer.new(attributes.arguments)
        @type = attributes.type
        @limit_to = attributes.limit_to
        @defines = attributes.defines
        @requires = attributes.requires

        # Flags for skipping anything else
        @skip_flags = Set.new

        # Store the command on the arguments, so we can access for error reporting
        @arguments.command = self

        # Pre load
        @permissions = Base::Permissions.new(self)
        @checks = Base::Checks.new(self, attributes.skipped_checks)
      end

      # The entry point for a command
      # @note Do not handle exceptions anywhere in this commands lifecycle
      def execute(event)
        if event.is_a?(Discordrb::Commands::CommandEvent)
          from_discord(event)
        else
          from_server(event)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def usage
        @usage ||= "#{distinct} #{@arguments.map(&:to_s).join(" ")}"
      end

      # Don't memoize this, prefix can change based on when its called
      def distinct
        "#{prefix}#{@name}"
      end

      def offset
        distinct.size
      end

      def example
        I18n.t("commands.#{@name}.example", prefix: prefix, default: "")
      end

      def description
        I18n.t("commands.#{@name}.description", prefix: prefix, default: "")
      end

      def prefix
        return ESM.config.prefix if current_community&.command_prefix.nil?

        current_community.command_prefix
      end

      # The user that executed the command
      def current_user
        return @current_user if defined?(@current_user) && @current_user.present?
        return nil if @event.user.nil?

        user = ESM::User.where(discord_id: @event.user.id).first_or_initialize
        user.update(
          discord_username: @event.user.name,
          discord_discriminator: @event.user.discriminator
        )

        # Save some cycles
        discord_user = user.discord_user
        discord_user.instance_variable_set("@esm_user", user)

        # Return back the modified discord user
        @current_user = discord_user
      end

      # @return [ESM::Community, nil] The community the command was executed from. Nil if sent from Direct Message
      def current_community
        return @current_community if defined?(@current_community) && @current_community.present?
        return nil if @event&.server.nil?

        @current_community = ESM::Community.find_by_guild_id(@event.server.id)
      end

      # @return [ESM::Cooldown] The cooldown for this command and user
      def current_cooldown
        @current_cooldown ||= load_current_cooldown
      end

      def current_channel
        @current_channel ||= @event.channel
      end

      # @return [ESM::Server, nil] The server that the command was executed for
      def target_server
        return nil if @arguments.server_id.blank?

        @target_server ||= ESM::Server.find_by_server_id(@arguments.server_id)
      end

      # @return [ESM::Community, nil] The community that the command was executed for
      def target_community
        @target_community ||= lambda do
          return ESM::Community.find_by_community_id(@arguments.community_id) if @arguments.community_id.present?

          # If we have a server ID, we can extract the community ID from it
          ESM::Community.find_by_server_id(@arguments.server_id) if @arguments.server_id.present?
        end.call
      end

      # @return [ESM::User, nil] The user that the command was executed against
      def target_user
        return @target_user if defined?(@target_user) && @target_user.present?
        return if @arguments.target.nil?

        # Store for later
        target = @arguments.target

        # Attempt to parse first. Target could be steam_uid, discord id, or mention
        user = ESM::User.parse(target)

        # No user was found. Don't create a user from a steam UID
        #   target is a steam_uid WITHOUT a db user. -> Exit early. Use a placeholder user
        return @target_user = ESM::TargetUser.new(target) if user.nil? && target.steam_uid?

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
        user.update(discord_username: discord_user.name, discord_discriminator: discord_user.discriminator)

        # Save some cycles
        discord_user.instance_variable_set("@esm_user", user)

        # Return back the modified discord user
        @target_user = discord_user
      end

      # Sometimes we're given a steamUID that may not be linked to a discord user
      # But, the command can work without the registered part.
      #
      # @return [String, nil] The steam uid from given argument or the steam uid registered to the target_user (which may be nil)
      def target_uid
        return if @arguments.target.nil?

        @target_uid ||= lambda do
          @arguments.target.steam_uid? ? @arguments.target : target_user&.steam_uid
        end.call
      end

      # @return [Boolean] If the current user is the target user.
      def same_user?
        return false if target_user.nil?

        current_user.steam_uid == target_user.steam_uid
      end

      def dm_only?
        @limit_to == :dm
      end

      def text_only?
        @limit_to == :text
      end

      def dev_only?
        @requires.include?(:dev)
      end

      def registration_required?
        @requires.include?(:registration)
      end

      def whitelist_enabled?
        @whitelist_enabled || false
      end

      def on_cooldown?
        # We've never used this command with these arguments before
        return false if current_cooldown.nil?

        current_cooldown.active?
      end

      # V1: Send a request to the DLL
      #
      # @param command_name [String, nil] V1: The name of the command to send to the DLL. Default: self.name.
      def deliver!(command_name: nil, timeout: 30, **parameters)
        raise ESM::Exception::CheckFailure, "Command does not have an associated server" if target_server.nil?

        # Build the request
        request =
          ESM::Websocket::Request.new(
            command: self,
            command_name: command_name,
            user: current_user,
            channel: current_channel,
            parameters: parameters,
            timeout: timeout
          )

        # Send it to the dll
        ESM::Websocket.deliver!(target_server.server_id, request)
      end

      #
      # Builds a ESM::Connection::Message from the provided data and sends it to `target_server`
      #
      # @return [ESM::Connection::Message] The message that was sent
      #
      def send_to_a3(type: self.name, **data)
        raise ESM::Exception::CheckFailure, "#send_to_a3 was called on #{self.name} but this command does not require a server" if target_server.nil?

        # Allows overwriting the outbound message. Otherwise, build a message from the data
        message = data[:message]
        if message.nil?
          message = ESM::Connection::Message.new(type: type, **data)
          message.add_callback(:on_error, :on_error)
          message.add_callback(:on_response) do |incoming_message, _outgoing_message|
            self.on_response(incoming_message)
          end
        end

        message.add_routing_data(command: self)
        message.apply_command_metadata
        target_server.connection.send_message(message)
      end

      # Convenience method for replying back to the event's channel
      def reply(message)
        ESM.bot.deliver(message, to: current_channel)
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

      # Raises an exception of the given class or ESM::Exception::CheckFailure.
      # If a block is given, the return of that block will be message to raise
      # Otherwise, it will build an error embed
      #
      # @deprecated
      # @see #raise_error!
      def check_failed!(name = nil, **args, &block)
        message =
          if block_given?
            yield
          elsif name.present?
            ESM::Embed.build(:error, description: I18n.t("command_errors.#{name}", **args.except(:exception_class)))
          end

        # Logging
        ESM::Notifications.trigger("command_check_failed", command: self, reason: message)

        raise args[:exception_class] || ESM::Exception::CheckFailure, message
      end

      #
      # Builds a message and raises a CheckFailure with that reason.
      #
      # @param error_name [String, Symbol, nil] The name of the error message located in the locales for "commands.<command_name>.errors". If nil, a block must be provided
      # @param args [Hash] The args to be passed into the translation if an error_name is provided
      # @param block [Proc] If provided, the block must return the error message to be used. This can be a string or an ESM::Embed.
      #
      # @replaces #check_failed!
      #
      def raise_error!(error_name = nil, **args, &block)
        exception_class = args.delete(:exception_class)

        reason =
          if block
            yield
          else
            ESM::Embed.build(:error, description: I18n.t("commands.#{self.name}.errors.#{error_name}", **args))
          end

        # Logging
        ESM::Notifications.trigger("command_check_failed", command: self, reason: reason)

        raise exception_class || ESM::Exception::CheckFailure, reason
      end

      #
      # Makes calls to I18n.t shorter
      #
      def t(translation_name, **args)
        I18n.t("commands.#{self.name}.#{translation_name}", **args)
      end

      private

      # @deprecated Use on_execute instead
      def discord; end

      # @deprecated Handled via ESM::Connection::Message
      def server; end

      def request_accepted; end

      def request_declined; end

      def from_discord(event)
        @event = event
        @executed_at = DateTime.now

        # Check permissions ahead of time so if the command is disabled, it doesn't try to correct argument errors
        @checks.permissions! if event.channel.text?

        # Check channel access due to argument parsing needing access to certain channels.
        @checks.text_only!
        @checks.dm_only!

        # Parse arguments or raises FailedArgumentParse
        @arguments.parse!(@event)

        # Logging
        ESM::Notifications.trigger("command_from_discord", command: self)

        # Run some checks
        @checks.run_all!

        # Call #on_execute. If the command is for a server version that is 1.0.0, load the V1 version of the command
        if target_server.present? && target_server.version < Semantic::Version.new("2.0.0")
          class_name = self.class.to_s

          # Initialize the v1 version of this command and give it the required data before calling #on_execute
          # If the v1 command is used, avoid initializing CommandV1V1
          command =
            if class_name.match?(/v1$/i)
              self
            else
              "#{class_name}V1".constantize.new
            end

          command.event = @event
          command.arguments = @arguments

          command.on_execute
        else
          on_execute
        end

        # Update the cooldown
        create_or_update_cooldown if !@skip_flags.include?(:cooldown)

        # Increment the counter
        ESM::CommandCount.increment_execution_counter(self.name)
      end

      #
      # V1: This is called when the message is received from the server
      #
      def from_server(parameters)
        # Parameters is always an array. 90% of the time, parameters size will only be 1
        # This just makes typing a little easier when writing commands
        @response = parameters.size == 1 ? parameters.first : parameters

        # Call the server method
        server
      end

      def create_or_update_cooldown
        query = ESM::Cooldown.where(command_name: @name)

        # If the command requires a steam_uid, use it to track the cooldown.
        query =
          if registration_required?
            query.where(steam_uid: current_user.steam_uid)
          else
            query.where(user_id: current_user.esm_user.id)
          end

        query = query.where(community_id: target_community.id) if target_community
        query = query.where(community_id: current_community.id) if current_community && target_community.nil?
        query = query.where(server_id: target_server.id) if target_server

        new_cooldown = query.first_or_create
        new_cooldown.update_expiry!(@executed_at, @permissions.cooldown_time)

        @current_cooldown = new_cooldown
      end

      def load_current_cooldown
        query = ESM::Cooldown.where(command_name: @name)

        # If the command requires a steam_uid, use it to track the cooldown.
        query =
          if registration_required?
            query.where(steam_uid: current_user.steam_uid)
          else
            query.where(user_id: current_user.esm_user.id)
          end

        # Check for the target_community
        query = query.where(community_id: target_community.id) if target_community

        # If we don't have a target_community, use the current_community (if applicable)
        query = query.where(community_id: current_community.id) if current_community && target_community.nil?

        # Check for the individual server
        query = query.where(server_id: target_server.id) if target_server

        # Fire the query and return the first result
        query.first
      end

      def skip(*flags)
        flags.each { |flag| @skip_flags << flag }
      end

      def handle_error(error)
        message = nil

        # So tests can check for errors
        raise error if ESM.env.test?

        case error
        when ESM::Exception::CheckFailure, ESM::Exception::FailedArgumentParse
          message = error.data
        when StandardError
          uuid = SecureRandom.uuid
          ESM.logger.error("#{self.class}##{__method__}") { ESM::JSON.pretty_generate(uuid: uuid, message: error.message, backtrace: error.backtrace) }

          message = ESM::Embed.build(:error, description: I18n.t("exceptions.system", error_code: uuid))
        else
          return
        end

        ESM.bot.deliver(message, to: @event.channel)
      end
    end
  end
end
