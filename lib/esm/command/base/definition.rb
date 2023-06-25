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
          class_attribute :type
          class_attribute :limited_to
          class_attribute :defines
          class_attribute :requirements
          class_attribute :skipped_actions
          class_attribute :has_v1_variant
        end

        class_methods do
          # ESM::Command::Server::SetId => set_id
          def command_name
            @command_name ||= name.demodulize.underscore.downcase.sub("_v1", "")
          end

          # ESM::Command::System::Accept => system
          def category
            @category ||= module_parent.name.demodulize.downcase
          end

          def argument(name, type = :string, **opts)
            arguments[name] = Argument.new(name, type, **opts.merge(command_name: command_name))
          end

          def set_type(type)
            self.type = type
          end

          def limit_to(channel_type)
            self.limited_to = channel_type
          end

          def define(attribute, **opts)
            defines[attribute] = Define.new(**opts)
          end

          def requires(*keys)
            self.requirements += keys
          end

          def skip_action(*actions)
            self.skipped_actions += actions
          end

          def inherited(child_class)
            child_class.__disconnect_variables!
            super
          end

          def __disconnect_variables!
            self.arguments = Arguments.new
            self.type = :player
            self.limited_to = nil
            self.defines = {}
            self.requirements = Set.new
            self.skipped_actions = Set.new
            self.has_v1_variant = false
          end
        end

        ############################################################
        ############################################################

        attr_reader :response # v1
        attr_reader :name, :description, :description_long, :example,
          :category, :cooldown_time, :permissions, :timers, :event

        attr_writer :current_community # Used in commands/general/help.rb

        def initialize
          command_class = self.class
          @name = command_class.command_name
          @category = command_class.category
          @description = I18n.t("commands.#{name}.description", default: "")
          @description_long = I18n.t("commands.#{name}.description_long", default: "")
          @example = I18n.t("commands.#{name}.example", default: "")

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
