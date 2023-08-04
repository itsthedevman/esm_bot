# frozen_string_literal: true

module ESM
  module Command
    CATEGORIES = %w[
      community
      development
      entertainment
      general
      server
      system
    ].freeze

    # @return [Array<Symbol>] A list of publicly available command types.
    #   Any types not in this list will not show up in the help documentation or on the website.
    TYPES = %i[admin player].freeze

    class << self
      attr_reader :all, :v1, :by_type,
        :by_namespace_for_server, :by_namespace_for_global, :by_namespace_for_all

      delegate :application_command, :register_application_command, to: "::ESM.bot"
    end

    def self.[](command_name)
      return if command_name.blank?

      command_name = command_name.to_s unless command_name.is_a?(String)

      # Find by name or by its usage (allowing / or no /)
      all.find { |command| command_name == command.command_name || command.usage.include?(command_name) }
    end

    def self.get(command_name)
      self[command_name]
    end

    # V1
    def self.get_v1(command_name)
      return if command_name.blank?

      command_name = command_name.to_s
      v1.find { |command| command_name == command.command_name }
    end

    def self.admin_commands
      by_type[:admin]
    end

    def self.player_commands
      by_type[:player]
    end

    def self.include?(command_name)
      !self[command_name].nil?
    end

    def self.load
      @all = []
      @v1 = [] # V1
      @by_type = []
      @by_namespace_for_server = {}
      @by_namespace_for_global = {}
      @by_namespace_for_all = {}

      commands_needing_cached = []
      ESM::Command::Base.subclasses.each do |command_class|
        # Background commands do not have types
        next if command_class.type.nil?

        # V1 - Skip because the V2 command is the one we want to cache
        if command_class.name.downcase.end_with?("v1")
          @v1 << command_class
          next
        end

        @all << command_class

        # Build the command structure for both server and global commands
        # Commands must be registered with Discord together if they share the same namespace
        register_namespace(command_class)

        # Only admin and player commands need to be cached
        next unless TYPES.include?(command_class.type)

        # To be written to the DB in bulk
        command = command_class.new
        commands_needing_cached << {
          command_name: command.name,
          command_type: command.type,
          command_category: command.category,
          command_description: command.description,
          command_example: command.example,
          command_usage: command.arguments.map(&:to_s).join(" "),
          command_arguments: command.arguments.to_s,
          command_defines: command.defines.to_h
        }
      end

      # Lock it!
      @all.freeze
      @by_type = @all.group_by(&:type).freeze
      @by_namespace_for_all = by_namespace_for_global.deep_merge(by_namespace_for_server)

      # Run some jobs for command
      RebuildCommandCacheJob.perform_async(commands_needing_cached)
      SyncCommandConfigurationsJob.perform_async(nil)
      SyncCommandCountsJob.perform_async(nil)
    end

    #
    # Returns configurations for all commands, often used for database inserts
    #
    # @return [Array<Hash>]
    #
    def self.configurations
      @configurations ||=
        ESM::Command.all.map do |command_class|
          command = command_class.new
          cooldown_default = command.defines.cooldown_time&.default || 2.seconds

          case cooldown_default
          when Enumerator, Integer
            cooldown_type = "times"
            cooldown_quantity = cooldown_default.size
          when ActiveSupport::Duration
            # Converts 2.seconds to [:seconds, 2]
            cooldown_type, cooldown_quantity = cooldown_default.parts.to_a.first
          else
            raise TypeError, "Invalid type \"#{cooldown_default.class}\" detected for command #{command.name}'s default cooldown"
          end

          # Written this way because the defaults can be `false` and `false || true` will always be `true`
          enabled =
            if (define = command.defines.enabled)
              define.default
            else
              true
            end

          allowed_in_text_channels =
            if (define = command.defines.allowed_in_text_channels)
              define.default
            else
              true
            end

          whitelist_enabled =
            if (define = command.defines.whitelist_enabled)
              define.default
            else
              command.type == :admin
            end

          # Except this one, but it just looks nice this way
          whitelisted_role_ids =
            if (define = command.defines.whitelisted_role_ids)
              define.default
            else
              []
            end

          {
            command_name: command.name,
            enabled: enabled,
            cooldown_quantity: cooldown_quantity,
            cooldown_type: cooldown_type,
            allowed_in_text_channels: allowed_in_text_channels,
            whitelist_enabled: whitelist_enabled,
            whitelisted_role_ids: whitelisted_role_ids
          }
        end
    end

    #
    # Using the namespaces of the commands, this method registers the event_hook with Discordrb so it's executed
    # when a command event occurs
    #
    def self.setup_event_hooks!
      by_namespace_for_all.each do |name, segments_or_command|
        # It's a command and it's at the root level
        if all.include?(segments_or_command)
          application_command(name, &segments_or_command.method(:event_hook))
          next
        end

        # It's a group and it may have subgroups or subcommands
        segments_or_command.each do |sub_name, segments_or_command|
          # It's a command!
          if all.include?(segments_or_command)
            application_command(name).subcommand(sub_name, &segments_or_command.method(:event_hook))
            next
          end

          # It's a group!
          application_command(name).group(sub_name) do |group|
            segments_or_command.each do |command_name, command|
              group.subcommand(command_name, &command.method(:event_hook))
            end
          end
        end
      end

      nil
    end

    #
    # Registers admin and development commands as "server commands" for the community
    # These are only present on the Discord and are not global
    #
    # @param community_discord_id [String, Integer] The community's guild ID
    #
    def self.register_server_commands(community_discord_id)
      by_namespace_for_server.each do |name, segments_or_command|
        register_command(name, segments_or_command, community_discord_id)
      end

      nil
    end

    #
    # Registers player commands as global since they can be used in DMs.
    # A guild ID can be provided to bind these to the community instead since global commands take time to become available (Discord reasons...)
    #
    # @param community_discord_id [String, Integer, nil] Optional. The community's guild ID
    #
    def self.register_global_commands(community_discord_id = nil)
      by_namespace_for_global.each do |name, segments_or_command|
        register_command(name, segments_or_command, community_discord_id)
      end

      nil
    end

    # @!visibility private
    def self.register_command(name, segments_or_command, community_discord_id)
      # It's a command and it's at the root level
      if all.include?(segments_or_command)
        segments_or_command.register_root_command(community_discord_id, name)
        return
      end

      # It's a group and it may have subgroups or subcommands
      ::ESM.bot.register_application_command(name, "C - If you are seeing this, something went wrong", server_id: community_discord_id) do |builder|
        segments_or_command.each do |name, segments_or_command|
          # It's a command!
          if all.include?(segments_or_command)
            segments_or_command.register_subcommand(builder, name)
            next
          end

          # It's a group!
          builder.subcommand_group(name, "G - If you are seeing this, something went wrong") do |group_builder|
            segments_or_command.each do |command_name, command|
              command.register_subcommand(group_builder, command_name)
            end
          end
        end
      end
    end

    # @!visibility private
    private_class_method def self.register_namespace(command_class)
      namespace = command_class.namespace
      segments = namespace[:segments]
      command_name = namespace[:command_name]

      # Only player commands are registered as global. Otherwise, it's a server registered command
      current_segment =
        if command_class.type == :player
          @by_namespace_for_global
        else
          @by_namespace_for_server
        end

      # Discord treats the first segment after the slash as the "command name"
      # Commands may use this as the root namespace (/help, /register)
      # Or this could be a single group (/community <command_name>)
      if (segment = segments.first)
        current_segment = current_segment[segment.to_sym] ||= {}
      end

      # Discord treats this as a "subgroup" after the "command name"
      # Commands may use this as a group namespace (/server admin <command_name>)
      if (segment = segments.second)
        current_segment = current_segment[segment.to_sym] ||= {}
      end

      # Ensure this namespace isn't already used
      if (namespaced_command = current_segment[command_name.to_sym])
        raise ESM::Exception::InvalidCommandNamespace,
          "#{command_class} attempted to bind to the namespace `/#{segments.join(" ")} #{command_name}` which is already bound to #{namespaced_command}"
      end

      # Finally store the command with the final segment (/server admin show)
      current_segment[command_name.to_sym] = command_class
    end
  end
end
