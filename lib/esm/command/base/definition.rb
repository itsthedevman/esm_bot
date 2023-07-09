# frozen_string_literal: true

module ESM
  module Command
    class Base
      # Methods involved with defining or creating a Command for ESM
      module Definition
        extend ActiveSupport::Concern

        # TYPES holds the various argument types Discord supports
        # Valid: string, integer, boolean, user, channel, role, mentionable, number, attachment
        ARGUMENT_TYPES = Discordrb::Interactions::OptionBuilder::TYPES.with_indifferent_access

        class Define < ImmutableStruct.define(:modifiable, :default)
          def initialize(modifiable: true, default: nil)
            super(modifiable: modifiable, default: default)
          end

          def modifiable?
            modifiable
          end
        end

        included do
          class_attribute :arguments
          class_attribute :category
          class_attribute :command_name
          class_attribute :defines
          class_attribute :description
          class_attribute :description_long
          class_attribute :example
          class_attribute :has_v1_variant
          class_attribute :limited_to
          class_attribute :namespace
          class_attribute :requirements
          class_attribute :skipped_actions
          class_attribute :type
        end

        class_methods do
          #
          # Defines an argument for this command
          #
          # @param name [Symbol] The name of the argument
          # @param type [Symbol] The Discord argument type
          # @param **opts [Hash] See ESM::Command::Argument#initialize
          #
          def argument(name, type = :string, **opts)
            arguments[name] = Argument.new(
              name, type,
              **opts.merge(command_name: command_name)
            )
          end

          #
          # Sets the command's type. Commonly :admin, :player, or :development
          #
          # @param type [Symbol, String]
          #
          def command_type(type)
            self.type = type.to_sym
          end

          #
          # Limits the command to a particular channel type.
          #
          # @param channel_type [Symbol, String] Valid options: :text, :pm
          #
          def limit_to(channel_type)
            self.limited_to = channel_type.to_sym
          end

          #
          # Defines an attribute on the command. These are used mainly for permissions
          #
          # @param attribute [Symbol, String] The name of the attribute
          # @param **opts [Hash] Configuration options. See ESM::Command::Define
          #
          def define(attribute, **opts)
            defines[attribute] = Define.new(**opts)
          end

          #
          # Sets a list of requirements for the command
          #
          # @param *keys [Symbol] The requirements. Valid options: :registration, :dev
          #
          def requires(*keys)
            self.requirements += keys
          end

          #
          # A list of check names that should be skipped during the lifecycle
          #
          # @param *actions [Array<Symbol>] The name of the actions to skip
          #
          def skip_action(*actions)
            self.skipped_actions += actions
          end

          #
          # Sets the command's namespace
          # When registered with Discord, each namespace is converted to: /<segments...> <command_name>
          #
          # @param *segments [Array<Symbol>] The individual segments
          # @param command_name [Symbol] The command name. Defaults to the result from `#command_name`
          #
          def command_namespace(*segments, command_name: self.command_name)
            raise ESM::Exception::InvalidCommandNamespace, "#{name}#command_namespace - Discord only supports one subgroup per command" if segments.size > 2

            self.namespace = {
              segments: segments.presence,
              command_name: command_name.to_sym
            }
          end

          #
          # Adds the root namespace (/esm <command_name>) to this command
          #
          # @return [<Type>] <description>
          #
          def use_root_namespace
            command_namespace([])
          end

          #
          # Adds the default namespace (/<category> <command_name>) to this command
          #
          def use_default_namespace
            command_namespace([category.to_sym])
          end

          # @!visibility private
          def inherited(child_class)
            child_class.__disconnect_variables!
            super
          end

          # @!visibility private
          def __disconnect_variables!
            self.arguments = Arguments.new
            self.defines = {}

            # ESM::Command::Territory::SetId => set_id
            self.command_name = name.demodulize.underscore.downcase.sub("_v1", "")

            # ESM::Command::Request::Accept => system
            self.category = module_parent.name.demodulize.downcase

            self.description = I18n.t("commands.#{command_name}.description", default: "")
            self.description_long = I18n.t("commands.#{command_name}.description_long", default: nil) || description
            self.example = I18n.t("commands.#{command_name}.example", default: "")
            self.has_v1_variant = false
            self.limited_to = nil
            self.namespace = []
            self.requirements = Set.new
            self.skipped_actions = Set.new
            self.type = :player
          end

          # @!visibility private
          def register(community_discord_id)
            use_default_namespace if namespace.nil?

            # If there are no segments, the command is a root level command
            command_prefix = namespace[:segments].first || namespace[:command_name]

            debug!(command_name: command_name, command_prefix: command_prefix)

            # Description must be less than 100 characters (Discord requirement)
            ::ESM.bot.register_application_command(command_prefix, "COMMAND", server_id: community_discord_id) do |command_builder|
              # A command can have up to one subgroup
              if (subgroup_prefix = namespace[:segments].second)
                command_builder.subcommand_group(subgroup_prefix.to_sym, "GROUP") do |subgroup_builder|
                  register_command(subgroup_builder, command_name)
                end
              else
                register_command(command_builder, command_name)
              end
            end
          end

          # @!visibility private
          def register_command(command_group, command_name)
            # Description must be less than 100 characters (Discord requirement)
            command_group.subcommand(command_name.to_sym, description.truncate(100)) do |arg_builder|
              arguments.each do |(_argument_name, argument)|
                if !ARGUMENT_TYPES.key?(argument.type)
                  raise ESM::Exception::InvalidCommandArgument, "Invalid type provided for argument #{argument.to_h}"
                end

                info!(
                  command: self.command_name,
                  command_name: command_name,
                  argument: {name: argument.name, type: argument.type}
                )

                arg_builder.public_send(
                  argument.type,
                  argument.name,
                  argument.description,
                  **argument.options
                )
              end
            end
          end
        end

        ############################################################
        ############################################################

        attr_reader :response # v1
        attr_reader :name, :category, :cooldown_time, :permissions, :timers, :event

        attr_writer :current_community # Used in commands/general/help.rb

        def initialize
          command_class = self.class
          @name = command_class.command_name
          @category = command_class.category

          @skipped_actions = ActiveSupport::ArrayInquirer.new(skipped_actions.to_a)
          @requirements = ActiveSupport::ArrayInquirer.new(requirements.to_a)
          @defines = defines.to_istruct

          # Mainly for specs, but does give performance analytics (which is a nice bonus)
          @timers = Timers.new(name)
        end
      end
    end
  end
end
