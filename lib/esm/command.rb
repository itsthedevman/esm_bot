# frozen_string_literal: true

module ESM
  module Command
    CATEGORIES = %w[development general server community entertainment system].freeze

    # @return [Array<Symbol>] A list of publicly available command types.
    #   Any types not in this list will not show up in the help documentation or on the website.
    TYPES = %i[admin player].freeze

    class << self
      attr_reader :all, :v1
    end

    def self.[](command_name)
      return if command_name.blank?

      @all.find { |command| command_name == command.name || command.command_aliases.include?(command_name.to_sym) }
    end

    # V1
    def self.get_v1(command_name)
      return if command_name.blank?

      @v1.find { |command| command_name == command.name }
    end

    def self.include?(command_name)
      !self[command_name].nil?
    end

    def self.load_commands
      @all = []
      @v1 = [] # V1
      @by_category = nil
      @by_type = nil
      @cache = []

      path = File.expand_path("lib/esm/command")
      CATEGORIES.each do |category|
        Dir["#{path}/#{category}/*.rb"].each do |command_path|
          if command_path.include?("v1") # V1
            process_command_v1(command_path, category) # V1
          else
            process_command(command_path, category)
          end
        end
      end

      # Load all of our test commands
      # Can't load in spec_helper because of race condition
      if ESM.env.test?
        path = File.expand_path("spec/support/esm/command/test")
        Dir["#{path}/*.rb"].each do |command_path|
          process_command(command_path, "test")
        end
      end

      # Lock it!
      @all.freeze

      # Run some jobs for command
      RebuildCommandCacheJob.perform_async(@cache)
      SyncCommandConfigurationsJob.perform_async(nil)
      SyncCommandCountsJob.perform_async(nil)

      # Free up the memory
      @cache = nil
    end

    def self.process_command(command_path, category)
      command_name = parse_command_name_from_path(command_path)

      # Create our command to be stored
      command = build(command_name, category)

      # Tell the bot about our command
      ESM::Bot.register_command(command.class, command.name.to_sym, command.aliases)

      # Cache Command
      cache(command)
    end

    # V1
    def self.process_command_v1(command_path, category)
      command_name = parse_command_name_from_path(command_path)
      command = build(command_name, category)
      return if command.type.nil?

      @v1 << command.class
    end

    def self.parse_command_name_from_path(command_path)
      command_path.gsub("#{File.expand_path("..", command_path)}/", "").gsub(/\.rb$/, "")
    end

    def self.build(command_name, category)
      # set_id -> SetId or pay -> Pay
      command_name = command_name.classify(keep_plural: true)
      category = category.classify(keep_plural: true)

      # "ESM::Command::Server::Pay" -> ESM::Command::Server::Pay -> New instance
      "ESM::Command::#{category}::#{command_name}".constantize.new
    end

    def self.cache(command)
      # Background commands do not have types
      return if command.type.nil?

      # Use command_name instead of command.name to get set_id instead of setid
      @all << command.class

      # Don't cache invalid command types.
      return if !TYPES.include?(command.type)

      # To be written to the DB in bulk
      @cache << {
        command_name: command.name,
        command_type: command.type,
        command_category: command.category,
        command_description: command.description,
        command_example: command.example,
        command_usage: command.arguments.map(&:to_s).join(" "),
        command_arguments: command.arguments.to_s,
        command_aliases: command.aliases,
        command_defines: command.defines.to_h
      }
    end

    def self.by_category
      @by_category ||= OpenStruct.new(@all.group_by(&:category.downcase))
    end

    def self.by_type
      @by_type ||= OpenStruct.new(@all.group_by(&:command_type))
    end

    #
    # Returns configurations for all commands, often used for database inserts
    #
    # @return [Array<Hash>]
    #
    def self.configurations
      @configurations ||=
        ESM::Command.all.map do |command|
          cooldown_default = command.defines.cooldown_time.default

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

          {
            command_name: command.name,
            enabled: command.defines.enabled.default,
            cooldown_quantity: cooldown_quantity,
            cooldown_type: cooldown_type,
            allowed_in_text_channels: command.defines.allowed_in_text_channels.default,
            whitelist_enabled: command.defines.whitelist_enabled.default,
            whitelisted_role_ids: command.defines.whitelisted_role_ids.default
          }
        end
    end
  end
end
