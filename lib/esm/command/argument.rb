# frozen_string_literal: true

module ESM
  module Command
    class Argument
      DEFAULTS = {
        community_id: {
          regex: ESM::Regex::COMMUNITY_ID_OPTIONAL,
          description: "default_arguments.community_id",
          modifier: lambda do |argument|
            # User alias
            # User default
            return if argument.content.present?
            return unless current_channel.text?

            argument.content = current_community.community_id
          end
        },
        target: {
          regex: ESM::Regex::TARGET,
          description: "default_arguments.target"
        },
        server_id: {
          regex: ESM::Regex::SERVER_ID_OPTIONAL_COMMUNITY,
          description: "default_arguments.server_id",
          preserve: true,
          modifier: lambda do |argument|
            if argument.content.present?
              # User provided - Starts with a community ID
              return if argument.content.match("^#{ESM::Regex::COMMUNITY_ID_OPTIONAL.source}_")

              # User alias
              if (id_alias = current_user.id_aliases.find_server_alias(argument.content))
                argument.content = id_alias.server.server_id
                return
              end

              # Community autofill
              if current_channel.text?
                argument.content = "#{current_community.community_id}_#{argument.content}"
              end

              return # Keep whatever was given - it'll be validated later
            end

            # Nothing was provided for this argument
            # Attempt to find and use a default

            # Community Defaults
            if current_channel.text?
              # Channel default
              channel_default = current_community.id_defaults.for_channel(current_channel)
              if channel_default&.server_id
                argument.content = channel_default.server.server_id
                return
              end

              # Global default
              global_default = current_community.id_defaults.global
              if global_default&.server_id
                argument.content = global_default.server.server_id
                return
              end
            end

            # User Default
            if current_user.id_defaults.server_id
              argument.content = current_user.id_defaults.server.server_id
              return
            end

            # Nothing was provided - it'll be validated later
          end
        },
        territory_id: {
          regex: ESM::Regex::TERRITORY_ID,
          description: "default_arguments.territory_id"
        }
      }.freeze

      # argument :name, regex: /xxx/, preserve: true, type: :integer, display_as: "", multiline: true, default: nil, modifier: ->(_argument) {}
      attr_reader :name, :parser, :opts, :match
      attr_accessor :content

      def initialize(name, opts = {})
        @name = name
        @opts = load_options(opts)
        @content = nil
        @match = nil

        # Run some checks on the argument
        check_for_regex!
        check_for_description!

        trace!(name: name, opts: opts)
      end

      def parse(message, command)
        # Parse the content from the message and store it
        parser = ESM::Command::Argument::Parser.new(self)
        @match, @content = parser.parse(message)

        # Arguments can opt to modify the parsed value (this is how auto-fill works)
        command.instance_exec(self, &modifier) if modifier?

        trace!(
          argument: {
            display: to_s,
            regex: regex,
            default: default
          },
          input: message,
          match: match,
          output: {
            type: content.class.name,
            content: content
          }
        )
      end

      def regex
        @regex ||= begin
          options = Regexp::IGNORECASE
          options += Regexp::MULTILINE if multiline?

          regex = "(#{opts[:regex].source})"
          regex += "?" if !required?

          Regexp.new(regex, options)
        end
      end

      def preserve_case?
        opts[:preserve] ||= false
      end

      def optional!
        self.default = nil
      end

      def required?
        !opts.key?(:default)
      end

      def type
        opts[:type] ||= :string
      end

      def display_as
        opts[:display_as] ||= name.to_s
      end

      def multiline?
        opts[:multiline] ||= false
      end

      def default=(value)
        opts[:default] = value
      end

      def default
        opts[:default]
      end

      def modifier
        opts[:modifier]
      end

      def modifier?
        modifier&.respond_to?(:call)
      end

      # Setting this to true will allow the ArgumentContainer to skip removing the matched contents of the message
      # so they can be matched by the next argument.
      def skip_removal=(value)
        opts[:skip_removal] = value
      end

      def skip_removal?
        opts[:skip_removal] ||= false
      end

      def default?
        !default.blank?
      end

      # Only valid if argument has content and no default.
      # Allows content to be nil if not required
      def invalid?
        required? && content.nil?
      end

      def description(prefix = ESM.config.prefix || "!")
        return "" if opts[:description].blank?

        # Call I18n with the name of the translation and pass the prefix into the translation by default
        I18n.send(:t, opts[:description], prefix: prefix, default: "")
      end

      def to_s
        name =
          if display_as.present?
            display_as.to_s
          else
            self.name.to_s
          end

        "<#{"?" if !required?}#{name}>"
      end

      private

      def check_for_regex!
        raise ESM::Exception::InvalidCommandArgument, "Missing regex for argument :#{name}" if opts[:regex].nil?
      end

      def check_for_description!
        raise ESM::Exception::InvalidCommandArgument, "Missing description for argument :#{name}" if opts[:description].nil?
      end

      def load_options(opts)
        argument_name = opts[:template] || name

        if DEFAULTS.key?(argument_name)
          DEFAULTS[argument_name].merge(opts)
        else
          opts
        end
      end
    end
  end
end
