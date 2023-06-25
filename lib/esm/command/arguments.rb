# frozen_string_literal: true

module ESM
  module Command
    class Arguments < Hash
      def load(input)
      end
      
      def validate!
        each { |argument| invalid_argument!(argument) if argument.invalid? }
      end

      def to_s
        return "" if empty?

        format(join_with: "\n\n") do |_name, argument|
          argument.help_documentation
        end
      end

      def invalid_argument!(argument)
        embed =
          ESM::Embed.build do |e|
            e.title = "**Missing argument `#{argument}` for `#{command.distinct}`**"
            e.description = "```#{command.distinct} #{build_error_description}```"

            e.add_field(
              name: "Arguments",
              value: map { |argument| argument.help_documentation(command) }
            )

            e.footer = "For more information, send me `#{command.prefix}help #{command.name}`"
          end

        raise ESM::Exception::FailedArgumentParse, embed
      end
    end
  end
end
