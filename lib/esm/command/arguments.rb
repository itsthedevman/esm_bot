# frozen_string_literal: true

module ESM
  module Command
    class Arguments < Hash
      def initialize(**inbound_arguments)
        merge!(**inbound_arguments)
        bind_hooks
      end

      def validate!(validators, command: nil)
        check_for_invalid_arguments!(validators, command)
      end

      def inspect
        ESM::JSON.pretty_generate(self)
      end

      def method_missing(method_name, *arguments, &block)
        self[method_name]
      end

      def respond_to_missing?(method_name, _include_private = false)
        key?(method_name) || super
      end

      private

      def check_for_invalid_arguments!(validators, command)
        invalid_arguments =
          validators.filter_map do |(name, validator)|
            # Apply pre-defined transformations and then validate the content
            self[name] = validator.transform_and_validate!(self[name], command)

            nil
          rescue ESM::Exception::InvalidArgument => argument
            argument
          end

        return if invalid_arguments.empty?

        raise ESM::Exception::CheckFailure, ESM::Embed.build do |e|
          e.title = "**Invalid #{"argument".pluralize(invalid_arguments.size)}**"
          e.description = "TODO"

          help_command = ESM::Command.get(:help)
          e.footer = "For more information, use `#{help_command.statement(category: command.command_name)}`"
        end
      end

      def bind_hooks
        each do |name, value|
          define_method(name) { value }
        end
      end
    end
  end
end
