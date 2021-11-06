# frozen_string_literal: true

module ESM
  class Bot < Discordrb::Commands::CommandBot
    # View Channels
    # Send Messages
    # Embed Links
    # Attach Files
    # Add Reactions
    PERMISSION_BITS = 52_288

    STATUS_TYPES = {
      PLAYING: 0,
      STREAMING: 1,
      LISTENING: 2,
      WATCHING: 3
    }.freeze

    attr_reader :config, :prefix

    attr_reader :resend_queue if ESM.env.test?

    def initialize
      @waiting_for = {}
      @mutex = Mutex.new

      @prefixes = {}
      @prefixes.default = ESM.config.prefix

      # Connect to the database
      ESM::Database.connect!

      load_community_prefixes
      @resend_queue = ESM::Bot::ResendQueue.new(self)

      super(token: ESM.config.token, prefix: method(:determine_activation_prefix), help_command: false)
    end

    def run
      # Binds the Discord Events
      bind_events!

      # Register all of ESM's commands
      ESM::Command.load_commands

      # Call Discordrb::Commands::Commandbot.run
      super
    end

    def stop
      return if stopping?

      @esm_status = :stopping
      ESM::Websocket::Server.stop
      ESM::Connection::Server.stop!
      ESM::Request::Overseer.die
      @resend_queue.die

      super
    end

    # Overriding DiscordRB's variant to allow commands to be case-insensitive
    def simple_execute(chain, event)
      return nil if chain.empty?

      args = chain.split
      execute_command(args[0].downcase.to_sym, event, args[1..])
    end

    ###########################
    # Discord Events!
    # These all have to have unique-to-ESM names since we are inheriting
    ###########################
    def bind_events!
      self.mention { |event| esm_mention(event) }
      self.ready { |event| esm_ready(event) }
      self.server_create { |event| esm_server_create(event) }
      self.user_ban { |event| esm_user_ban(event) }
      self.user_unban { |event| esm_user_unban(event) }
      self.member_join { |event| esm_member_join(event) }
    end

    def esm_mention(_event)
      # This event is raised when the bot is mentioned in a message.
    end

    def esm_ready(_event)
      ESM::Notifications.trigger("ready")

      bot_attributes = ESM::BotAttribute.first

      # status, activity, url, since = 0, afk = false, activity_type = 0
      update_status("online", bot_attributes.status_message, nil, activity_type: STATUS_TYPES[bot_attributes.status_type]) if bot_attributes.present?

      # Sometimes the bot loses connection with Discord. Upon reconnect, the ready event will be triggered again.
      # Don't restart the websocket server again.
      return if self.ready?

      # Wait until the bot has connected before starting the websocket.
      # This is to avoid servers connecting before the bot is ready
      ESM::API.run!

      # V1
      ESM::Websocket.start!
      ESM::Request::Overseer.watch
      # V1

      ESM::Connection::Server.run!

      @esm_status = :ready
    end

    def esm_server_create(event)
      # This event is raised when a server is created respective to the bot
      ESM::Event::ServerCreate.new(event.server).run!
    end

    def esm_user_ban(event)
      # This event is raised when a user is banned from a server.
      # IDEA: Ask the banning admin if they would also like to ban the user on the server
    end

    def esm_user_unban(event)
      # This event is raised when a user is unbanned from a server.
    end

    # Fires when a member joins a Discord server
    def esm_member_join(event)
      return if ESM.env.development? && ESM.config.dev_user_whitelist.include?(event.user.id.to_s)

      ESM::Event::MemberJoin.new(event).run!
    end

    ###########################
    # Public Methods
    ###########################
    def stopping?
      @esm_status == :stopping
    end

    def ready?
      @esm_status == :ready
    end

    def deliver(message, to:)
      return if message.blank?

      message = message.join("\n") if message.is_a?(Array)

      delivery_channel = determine_delivery_channel(to)
      raise ESM::Exception::ChannelNotFound.new(message, to) if delivery_channel.nil?

      ESM::Notifications.trigger("bot_deliver", message: message, channel: delivery_channel)

      # So we can test if it's working
      # env.error_testing? is to allow testing of errors without sending messages
      discord_message =
        if ESM.env.test? || ESM.env.error_testing?
          ESM::Test.messages.store(message, delivery_channel)
        elsif message.is_a?(ESM::Embed)
          # Send the embed
          delivery_channel.send_embed { |embed| message.transfer(embed) }
        else
          # Send the text message
          delivery_channel.send_message(message)
        end

      # Dequeue the message if it was enqueued
      @resend_queue.dequeue(message, to: to)

      # Return the Discordrb::Message
      discord_message
    rescue ESM::Exception::ChannelAccessDenied
      community = ESM::Community.find_by_guild_id(delivery_channel.server.id)
      embed = ESM::Embed.build(:error, description: I18n.t("exceptions.deliver_failure", channel_name: delivery_channel.name, message: message))
      community.log_event(:error, embed)
    rescue StandardError => e
      ESM::Notifications.trigger("warn", class: self.class, method: __method__, error: e)
      @resend_queue.enqueue(message, to: to, exception: e)

      nil
    end

    # Also see #wait_for_reply
    def await_response(responding_user, expected:, timeout: nil)
      counter = 0
      match = nil
      invalid_response = format_invalid_response(expected)
      responding_user = self.user(responding_user)

      while match.nil? && counter < 99
        response =
          if ESM.env.test?
            ESM::Test.await(timeout: timeout)
          else
            # Add the await event
            responding_user.await!(timeout: timeout)
          end

        # We timed out
        break if response.nil?

        # Parse the match from the event
        match = response.message.content.match(Regexp.new("(#{expected.map(&:downcase).join("|")})", Regexp::IGNORECASE))

        # We found what we were looking for
        break if !match.nil?

        # Let the user know that was not quite what we were looking for
        self.deliver(invalid_response, to: responding_user)

        counter += 1
      end

      raise ESM::Exception::CheckFailure, I18n.t("failure_to_communicate") if match.nil?

      # Return the match
      match[1]
    end

    def update_community_prefix(community)
      @prefixes[community.guild_id] = community.command_prefix
    end

    # Channel can be any of the following: An CommandEvent, a Channel, a User/Member, or a String (Channel, or user)
    def determine_delivery_channel(channel)
      return if channel.nil?

      channel =
        case channel
        when Discordrb::Commands::CommandEvent
          channel.channel
        when Discordrb::Channel
          channel
        when ESM::User
          channel.discord_user.pm
        when Discordrb::Member, Discordrb::User
          channel.pm
        when String, Numeric
          # Try checking if it's a text channel
          temp_channel = self.channel(channel)

          # Okay, it might be a PM channel, just go with it regardless (it returns nil)
          if temp_channel.nil?
            self.pm_channel(channel)
          else
            temp_channel
          end
        end

      return if channel.nil?
      return channel if channel.pm?

      raise ESM::Exception::ChannelAccessDenied if !self.channel_permission?(channel, :read_messages)
      raise ESM::Exception::ChannelAccessDenied if !self.channel_permission?(channel, :send_messages)

      channel
    end

    def update_prefix(community)
      @prefixes[community.guild_id] = community.command_prefix || ESM.config.prefix
    end

    #
    # Checks if the bot has send permission to the provided channel
    #
    # @param channel [Discordrb::Channel] The channel to check
    #
    # @return [Boolean]
    #
    def channel_permission?(channel, permission)
      member = self.profile.on(channel.server)
      member.permission?(permission, channel)
    end

    #
    # Successor to #await_response. Waits for an event from user_id and channel_id
    #
    # @param user_id [Integer/String] The ID of the user who sends the message
    # @param channel_id [Integer/String] The ID of the channel where the message is sent to. The bot must be a member of said channel
    # @param expires_at [DateTime, Time] When this time is reached, the callback will be called with `nil` for the event
    # @param &callback [Proc] The code to execute once the message has been received
    #
    # @return [true]
    #
    def wait_for_reply(user_id:, channel_id:, expires_at: 5.minutes.from_now, &callback)
      @mutex.synchronize do
        @waiting_for[user_id] ||= []
        @waiting_for[user_id] << channel_id
      end

      # Event will be nil if it times out
      timeout = expires_at - ::Time.now
      event =
        if ESM.env.test?
          ESM::Test.await(timeout: timeout)
        else
          self.add_await!(Discordrb::Events::MessageEvent, { from: user_id, in: channel_id, timeout: timeout })
        end

      @mutex.synchronize do
        @waiting_for[user_id]&.delete_if { |id| id == channel_id }
      end

      return event unless callback

      yield(event)
      nil
    end

    def waiting_for_reply?(user_id:, channel_id:)
      @mutex.synchronize do
        channel_ids = @waiting_for[user_id]
        return false if channel_ids.blank?

        channel_ids.include?(channel_id)
      end
    end

    private

    def load_community_prefixes
      ESM::Community.all.each do |community|
        next if community.command_prefix.nil?

        @prefixes[community.guild_id] = community.command_prefix
      end
    end

    def determine_activation_prefix(message)
      # The default for @prefixes is the config prefix (NOT NIL)
      prefix = @prefixes[message.channel&.server&.id.to_s]
      return if !message.content.start_with?(prefix)

      message.content[prefix.size..]
    end

    def format_invalid_response(expected)
      expected_string = expected.map { |value| "`#{value}`" }.join(" or ")
      I18n.t("invalid_response", expected: expected_string)
    end
  end
end
