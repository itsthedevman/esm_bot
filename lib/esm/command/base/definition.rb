# frozen_string_literal: true

module ESM
  module Command
    class Base
      # Methods involved with defining or creating a Command for ESM
      module Definition
        extend ActiveSupport::Concern

        class Define < Struct.new(:modifiable, :default)
          attr_predicate :modifiable

          def initialize(modifiable: true, default: nil)
            super(modifiable: modifiable, default: default)
          end
        end

        included do
          class_attribute :arguments
          class_attribute :attributes
          class_attribute :category
          class_attribute :command_name
          class_attribute :description
          class_attribute :description_extra
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
              **opts.merge(command_class: self)
            )
            self
          end

          #
          # Sets the command's type. Commonly :admin, :player, or :development
          #
          # @param type [Symbol, String]
          #
          def command_type(type)
            self.type = type.to_sym
            self
          end

          #
          # Limits the command to a particular channel type.
          #
          # @param channel_type [Symbol, String] Valid options: :text, :pm
          #
          def limit_to(channel_type)
            self.limited_to = channel_type.to_sym
            self
          end

          #
          # Changes an attribute on the command. These are used mainly for permissions
          #
          # @param attribute [Symbol, String] The name of the attribute
          # @param **opts [Hash] Configuration options. See ESM::Command::Define
          #
          def change_attribute(attribute, **opts)
            if !attributes.key?(attribute)
              raise ArgumentError, "Invalid attribute provided: #{attribute}. Expected one of: #{attributes.keys}"
            end

            attribute = attributes[attribute]
            opts.each { |k, v| attribute.send("#{k}=", v) }
            self
          end

          #
          # Sets a list of requirements for the command
          #
          # @param *keys [Symbol] The requirements. Valid options: :registration, :dev
          #
          def requires(*keys)
            requirements.set(*keys)
            self
          end

          #
          # A list of check names that should be skipped during the lifecycle
          #
          # @param *actions [Array<Symbol>] The name of the actions to skip
          #
          def skip_action(*actions)
            skipped_actions.set(*actions)
            self
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
              segments: segments.presence || [],
              command_name: command_name.to_sym
            }

            self
          end

          #
          # Adds the root namespace (/esm <command_name>) to this command
          #
          alias_method :use_root_namespace, :command_namespace

          #
          # Returns a hash representation of this command
          #
          # @return [Hash]
          #
          def to_h
            {
              command_name: command_name,
              type: type,
              category: category,
              namespace: namespace,
              has_v1_variant: has_v1_variant,
              limited_to: limited_to,
              attributes: attributes,
              requirements: requirements.to_h,
              skipped_actions: skipped_actions.to_h,
              arguments: arguments,
              description: description,
              description_extra: description_extra,
              example: example
            }
          end

          #
          # Returns the JSON representation of this command
          #
          # @return [String]
          #
          def to_json(...)
            to_h.to_json(...)
          end

          # @!visibility private
          def inherited(child_class)
            child_class.__disconnect_variables!
            super
          end

          # @!visibility private
          def __disconnect_variables!
            self.arguments = {}

            self.attributes = {
              enabled: Define.new(default: true),
              whitelist_enabled: Define.new(default: false),
              whitelisted_role_ids: Define.new(default: []),
              allowed_in_text_channels: Define.new(default: true),
              cooldown_time: Define.new(default: 2.seconds)
            }

            # ESM::Command::Territory::SetId => set_id
            name = self.name.demodulize.underscore.downcase
            self.command_name = name.sub("_v1", "")

            # ESM::Command::Request::Accept => system
            self.category = module_parent.name.demodulize.downcase

            command_namespace(category.to_sym) # Sets the default namespace to be: /<category> <command_name>

            self.description = I18n.t("commands.#{name}.description", default: "")
            self.description_extra = I18n.t("commands.#{name}.description_extra", default: nil)
            self.example = I18n.t("commands.#{name}.example", default: "")
            self.has_v1_variant = false
            self.limited_to = nil
            self.type = :player

            self.requirements = Inquirer.new(:dev, :registration)
            self.skipped_actions = Inquirer.new(
              :connected_server, :cooldown, :nil_target_user,
              :nil_target_server, :nil_target_community, :different_community
            )

            check_for_valid_configuration!
          end

          # @!visibility private
          def register_root_command(community_discord_id, command_name)
            ::ESM.bot.register_application_command(
              command_name,
              description,
              server_id: community_discord_id
            ) do |builder, _permission_builder|
              register_arguments(builder)
            end
          end

          # @!visibility private
          def register_subcommand(builder, command_name)
            builder.subcommand(command_name.to_sym, description, &method(:register_arguments))
          end

          # @!visibility private
          def register_arguments(builder)
            # Required arguments must be first (Discord requirement)
            sorted_arguments = arguments.values.sort_by { |argument| argument.required? ? 0 : 1 }

            sorted_arguments.each do |argument|
              if !builder.respond_to?(argument.type)
                raise ESM::Exception::InvalidCommandArgument, "Invalid type provided for argument #{argument.to_h}"
              end

              info!(
                command: command_name,
                argument: {name: argument.name, type: argument.type}
              )

              builder.public_send(
                argument.type,
                argument.name,
                argument.description,
                **argument.options
              )
            end

            info!(command: command_name, status: :registered)
          end

          # @!visibility private
          def check_for_valid_configuration!
            if description.length > 100
              raise ArgumentError, "#{name} - description cannot be longer than 100 characters"
            end

            if description.length < 1
              raise ArgumentError, "#{name} - description must be at least 1 character long"
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
          @attributes = attributes.to_istruct
          @arguments = ESM::Command::Arguments.new(**command_class.arguments)

          # Mainly for specs, but does give performance analytics (which is a nice bonus)
          @timers = Timers.new(name)
        end
      end
    end
  end
end
