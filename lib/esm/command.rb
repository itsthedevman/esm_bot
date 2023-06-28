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
      attr_reader :all, :v1
    end

    def self.[](command_name)
      return if command_name.blank?

      command_name = command_name.to_s
      @all.find { |command| command_name == command.command_name }
    end

    # V1
    def self.get_v1(command_name)
      return if command_name.blank?

      command_name = command_name.to_s
      @v1.find { |command| command_name == command.command_name }
    end

    def self.by_type
      @by_type
    end

    def self.admin_commands
      @by_type[:admin]
    end

    def self.player_commands
      @by_type[:player]
    end

    def self.include?(command_name)
      !self[command_name].nil?
    end

    def self.load
      @all = []
      @v1 = [] # V1
      @by_type = []

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
        next if !TYPES.include?(command_class.type)

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
  end
end
