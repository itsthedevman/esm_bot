# frozen_string_literal: true

module ESM
  module Command
    class Base
      # Methods involved with defining or creating a Command for ESM
      module Definition
        extend ActiveSupport::Concern

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
          class_attribute :namespaces
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
          # Adds a command definition namespace that is registered with Discord
          # When registered with Discord, each namespace is converted to: /esm <segments...> <command_name>
          #
          # @param *segments [Array<Symbol>] The individual segments
          # @param command_name [Symbol] The command name. Defaults to the result from `#command_name`
          #
          def add_namespace(segments = [], command_name: self.command_name)
            namespaces << {segments: segments, command_name: command_name.to_sym}
          end

          alias_method :use_root_namespace, :add_namespace

          #
          # Clears the command's namespace. Useful when the command has a special namespace and doesn't need the default
          #
          def clear_namespaces!
            self.namespaces = []
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

            # ESM::Command::System::Accept => system
            self.category = module_parent.name.demodulize.downcase

            self.description = I18n.t("commands.#{command_name}.description", default: "")
            self.description_long = I18n.t("commands.#{command_name}.description_long", default: nil) || description
            self.example = I18n.t("commands.#{command_name}.example", default: "")
            self.has_v1_variant = false
            self.limited_to = nil
            self.namespaces = [{segments: [category.to_sym], command_name: command_name}]
            self.requirements = Set.new
            self.skipped_actions = Set.new
            self.type = :player
          end

          # @!visibility private
          def register(command_builder)
            command_group = command_builder
            command_name = namespace[:command_name]
            segments = namespace[:segments]

            # Build the namespace `/esm namespaces...`
            segments.each do |segment|
              command_group.subcommand_group(segment, "") do |group|
                command_group = group
              end
            end

            # Now define the command itself and its arguments
            command_group.subcommand(command_name, description) do |arg_builder|
              valid_argument_types = arg_builder.class::TYPES

              arguments.each do |argument|
                if !valid_argument_types.key?(argument.type)
                  raise ESM::Exception::InvalidCommandArgument, "Invalid type provided for argument #{argument.to_h}"
                end

                arg_builder.option(
                  valid_argument_types[argument.type],
                  argument.name,
                  argument.description_short,
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
