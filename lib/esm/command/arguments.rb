# frozen_string_literal: true

module ESM
  module Command
    class Arguments < Hash
      attr_reader :templates, :command

      def initialize(command = nil, **templates)
        @command = command
        @templates = templates.symbolize_keys

        prepare
      end

      def validate!(**inbound_arguments)
        inbound_arguments = inbound_arguments.symbolize_keys

        # Check the inbound arguments against the templates
        # This collects all of the invalid arguments together and sends one message instead of breaking at the first invalid argument
        invalid_arguments =
          templates.filter_map do |(name, template)|
            # Apply pre-defined transformations and then validate the content
            self[name] = template.transform_and_validate!(inbound_arguments[name], command)

            nil
          rescue ESM::Exception::InvalidArgument => argument
            argument
          end

        # All the arguments are valid
        return if invalid_arguments.empty?

        embed =
          ESM::Embed.build do |e|
            e.title = "**Invalid #{"argument".pluralize(invalid_arguments.size)}**"
            e.description = invalid_arguments.format(&:help_documentation)

            help_command = ESM::Command.get(:help)
            e.footer = "For more information, use `#{help_command.usage(arguments: {category: command.command_name})}`"
          end

        raise ESM::Exception::CheckFailure, embed
      end

      def inspect
        ESM::JSON.pretty_generate(
          values: self,
          command: command&.command_name,
          templates: templates.map(&:to_h)
        )
      end

      def with_templates
        each_with_object({}) do |(name, value), hash|
          hash[name] = {
            value: value,
            template: templates[name]
          }
        end
      end

      ###
      # Allows referencing arguments that may not exist on the current command, but does on others
      def method_missing(method_name, *arguments, &block)
        self[method_name.to_sym]
      end

      def respond_to_missing?(method_name, _include_private = false)
        key?(method_name.to_sym) || super
      end
      #
      ###

      private

      def prepare
        return if templates.empty?

        templates.keys.each do |name|
          self[name] = nil

          define_method(name) { self[name] }
          define_method("#{name}=") { |value| self[name] = value }
        end
      end
    end
  end
end
