# frozen_string_literal: true

module ESM
  module Command
    class Base
      # Methods involved with defining or creating a Command for ESM
      module Definition
        extend ActiveSupport::Concern

        ATTRIBUTES = ImmutableStruct.define(*%i[
          name
          category
          aliases
          arguments
          type
          limit_to
          defines
          requires
          skipped_checks
        ])
        private_constant :ATTRIBUTES

        class_methods do
          attr_reader :defines, :type, :category, :aliases

          def name
            return @command_name if !@command_name.nil?

            super
          end

          def inherited(child_class)
            child_class.reset_variables!
            super
          end

          def reset_variables!
            @aliases = []
            @arguments = []
            @type = nil
            @limit_to = nil
            @defines = OpenStruct.new
            @requires = []
            @skipped_checks = Set.new
            @has_v1_variant = false

            # ESM::Command::System::Accept => system
            @category = module_parent.name.demodulize.downcase

            # ESM::Command::Server::SetId => set_id
            @command_name = name.demodulize.underscore.downcase
          end

          def argument(name, opts = {})
            @arguments << [name, opts]
          end

          def example(prefix = ESM.config.prefix)
            I18n.t("commands.#{@command_name}.example", prefix: prefix, default: "")
          end

          def description(prefix = ESM.config.prefix)
            I18n.t("commands.#{@command_name}.description", prefix: prefix, default: "")
          end

          def register_aliases(*aliases)
            @aliases = aliases
          end

          def set_type(type)
            @type = type
          end

          def limit_to(channel_type) # standard:disable Style/TrivialAccessors
            @limit_to = channel_type
          end

          def define(attribute, **opts)
            @defines[attribute] = OpenStruct.new(opts)
          end

          def requires(*keys)
            @requires = keys
          end

          def attributes
            ATTRIBUTES.new(
              name: @command_name.dup,
              category: @category.dup,
              aliases: @aliases.deep_dup,
              arguments: @arguments.deep_dup,
              type: @type,
              limit_to: @limit_to,
              defines: @defines.deep_dup,
              requires: @requires.deep_dup,
              skipped_checks: @skipped_checks.deep_dup
            )
          end

          def skip_check(*checks)
            checks.each do |check|
              @skipped_checks << check
            end
          end
        end

        ############################################################
        ############################################################

        # V1: name is defined in the migrations file, but will need to be added here once v1 has been deprecated
        attr_reader :category, :type, :aliases, :limit_to,
          :requires, :response, :cooldown_time,
          :defines, :permissions, :checks, :skip_flags,
          :timers, :event, :arguments, :argument_names

        attr_writer :current_community # Used in commands/general/help.rb

        def initialize
          attributes = self.class.attributes

          @name = attributes.name
          @category = attributes.category
          @aliases = attributes.aliases
          @argument_names = attributes.arguments.map(&:first)
          @arguments = ESM::Command::ArgumentContainer.new(self, attributes.arguments)
          @type = attributes.type
          @limit_to = attributes.limit_to
          @defines = attributes.defines
          @requires = attributes.requires

          # Mainly for specs, but does give performance analytics (which is a nice bonus)
          @timers = Timers.new(name)

          # Flags for skipping anything else
          @skip_flags = Set.new

          # Pre load
          @permissions = Base::Permissions.new(self)
          @checks = Base::Checks.new(self, attributes.skipped_checks)
        end
      end
    end
  end
end
