# frozen_string_literal: true

module ESM
  module Command
    class Arguments < Hash
      attr_reader :templates, :command_instance

      def initialize(command = nil, **templates)
        @command_instance = command
        @templates = templates.symbolize_keys

        # Map the display name to the name itself
        @display_name_mapping = templates.values.each_with_object({}) { |a, hash| hash[a.display_name] = a.name }

        prepare
      end

      def validate!(**inbound_arguments)
        inbound_arguments = inbound_arguments.symbolize_keys

        # Check the inbound arguments against the templates
        # This collects all of the invalid arguments together and sends one message instead of breaking at the first invalid argument
        invalid_arguments =
          templates.filter_map do |(name, template)|
            # Apply pre-defined transformations and then validate the content
            self[name] = template.transform_and_validate!(inbound_arguments[template.display_name], command_instance)

            nil
          rescue ESM::Exception::InvalidArgument => e
            e.data
          end

        # All the arguments are valid
        return if invalid_arguments.empty?

        embed =
          ESM::Embed.build do |e|
            command_usage = command_instance.usage(with_args: false, with_slash: false)
            help_usage = ESM::Command.get(:help).usage(with_args: true, overrides: {with: command_usage})
            help_documentation = invalid_arguments.format(join_with: "\n\n", &:help_documentation)

            e.title = "**Invalid #{"argument".pluralize(invalid_arguments.size)} for `/#{command_usage}`**"
            e.description = <<~STRING
              Please read the following and correct any errors before trying again.

              #{help_documentation}
            STRING

            e.add_field(
              name: I18n.t("commands.help.command.examples"),
              value: command_instance.example
            )

            e.footer = "For more information, use `#{help_usage}`"
          end

        raise ESM::Exception::CheckFailure, embed
      end

      def inspect
        ESM::JSON.pretty_generate(
          values: self,
          command: command_instance&.command_name,
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

      def template(name)
        name = name.to_sym
        mapping = @display_name_mapping[name] || name

        templates[mapping]
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

        templates.values.each do |argument|
          name = argument.name

          # self[server_id] = nil
          self[name] = nil

          # self.server_id
          define_method(name) { self[name] }

          # self.for #=> server_id
          define_method(argument.display_name) { self[name] }

          # self.server_id = value
          define_method("#{name}=") { |value| self[name] = value }
        end
      end
    end
  end
end
