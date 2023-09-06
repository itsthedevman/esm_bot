# frozen_string_literal: true

module ESM
  module Command
    class Argument
      DEFAULTS = {
        # Required: Majority of the time, this is needed.
        target: {
          checked_against: ESM::Regex::TARGET,
          description_extra: "commands.arguments.target.description_extra",
          description: "commands.arguments.target.description",
          required: true
        },

        # Required: Majority of the time, this is needed.
        command: {
          checked_against: ->(context) { ESM::Command.include?(context.content) },
          description: "commands.arguments.command.description",
          required: true
        },

        # Required: No functionality to "guess" this
        territory_id: {
          checked_against: ESM::Regex::TERRITORY_ID,
          description_extra: "commands.arguments.territory_id.description_extra",
          description: "commands.arguments.territory_id.description",
          required: true
        },

        # Optional: UserDefault/CommunityDefault can be used. It will be validated so it is "semi-required"
        community_id: {
          checked_against: ESM::Regex::COMMUNITY_ID,
          description_extra: "commands.arguments.community_id.description_extra",
          description: "commands.arguments.community_id.description",
          optional_text: "commands.arguments.community_id.optional_text",
          modifier: lambda do |context|
            if context.content.present?
              # User alias
              if (id_alias = current_user.id_aliases.find_community_alias(context.content))
                context.content = id_alias.community.community_id
                return
              end

              return # Keep whatever was given - it'll be validated later
            end

            # Nothing was provided for this argument
            # Attempt to find and use a default

            # User default
            if current_user.id_defaults.community_id
              context.content = current_user.id_defaults.community.community_id
              return
            end

            # Community autofill
            if current_channel.text?
              context.content = current_community.community_id
            end

            # Nothing was provided and there was no default - it'll be validated later
          end
        },

        # Optional: UserDefault/CommunityDefault can be used. It will be validated so it is "semi-required"
        server_id: {
          checked_against: ESM::Regex::SERVER_ID,
          description_extra: "commands.arguments.server_id.description_extra",
          description: "commands.arguments.server_id.description",
          optional_text: "commands.arguments.server_id.optional_text",
          modifier: lambda do |context|
            if context.content.present?
              # User provided - Starts with a community ID
              return if context.content.match("#{ESM::Regex::COMMUNITY_ID_OPTIONAL.source}_")

              # User alias
              if (id_alias = current_user.id_aliases.find_server_alias(context.content))
                context.content = id_alias.server.server_id
                return
              end

              # Community autofill
              if current_channel.text? && current_community.servers.by_server_id_fuzzy(context.content).any?
                context.content = "#{current_community.community_id}_#{context.content}"
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
                context.content = channel_default.server.server_id
                return
              end

              # Global default
              global_default = current_community.id_defaults.global
              if global_default&.server_id
                context.content = global_default.server.server_id
                return
              end
            end

            # User Default
            if current_user.id_defaults.server_id
              context.content = current_user.id_defaults.server.server_id
              return
            end

            # Nothing was provided and there was no default - it'll be validated later
          end
        }
      }.freeze

      # @!visibility private
      class ArgumentContext < Struct.new(:content, keyword_init: true)
      end
      private_constant :ArgumentContext

      attr_reader :name, :type, :discord_type,
        :display_name, :command_class, :command_name,
        :default_value, :cast_type, :modifier,
        :description, :description_extra, :optional_text,
        :options, :validator

      #
      # A configurable representation of a command argument
      #
      # @param name [Symbol, String]
      #     The argument's name
      #
      # @param type [Symbol, String]
      #     The argument's type (directly linked to Discord).
      #     Optional.
      #     Default: :string
      #
      # @param opts [Hash]
      #     Options to configure the argument
      #
      #   @option opts [Symbol] :required
      #     Controls if the argument should be required by Discord.
      #     Optional.
      #     Default: false
      #
      #   @option opts [Symbol, String, nil] :template
      #     The name of a default entry in which `opts` are merged into.
      #     Useful for having an argument that acts like another argument, but may have different configuration
      #
      #   @option opts [String] :description
      #     This argument's description, in less than 100 characters.
      #       This description is used in Discord when viewing the argument.
      #       Note: Providing this option is optional, however, all arguments MUST have a non-blank description
      #     This value defaults to the value located at the locale path:
      #         commands.<command_name>.arguments.<argument_name>.description
      #
      #   @option opts [String] :description_extra
      #     Any extra information to be included that wouldn't fit in the 100 character limit
      #       Note: Providing this option is optional, however, this argument MUST have a non-blank description
      #       This description is used in the help documentation with the help command and on the website
      #     This value defaults to the value located at the locale path:
      #         commands.<command_name>.arguments.<argument_name>.description_extra
      #
      #   @option opts [String] :optional_text
      #     Allows for overriding the "this argument is optional" text in the help documentation.
      #       This opt is ignored if `required: true`
      #     Optional.
      #     This value defaults to the value located at the locale path:
      #         commands.<command_name>.arguments.<argument_name>.optional_text
      #
      #   @option opts [Symbol, String] :display_name
      #     Changes how the argument is displayed to the user, but not in the code
      #     Optional.
      #
      #   @option opts [Object] :default
      #     The default value if this argument. This value is ignored if `required: true`
      #     Optional.
      #     Default: nil
      #
      #   @option opts [Boolean] :preserve_case
      #     Controls if this argument's value should be converted to lowercase or not.
      #     Optional.
      #     Default: false
      #
      #   @option opts [Symbol, Proc] :type_caster
      #     Performs extra casting once the value is received from Discord
      #       If the value is a Symbol, it will be be checked against the available options.
      #       If the value is a Proc, it will be called and the raw value passed in.
      #     Optional.
      #     Valid options: :json, :symbol
      #
      #   @option opts [Proc] :modifier
      #     A block of code used to modify this argument's value before validation
      #     Optional.
      #
      #   @option opts [Hash] :choices
      #     The key: display_value of choices the user can pick from
      #     Optional.
      #
      #   @option opts [Integer] :min_value
      #     If type is integer/number, this is the minimum value that can be selected
      #
      #   @option opts [Integer] :max_value
      #     If type is integer/number, this is the maximum value that can be selected
      #
      #   @option opts [nil, Regex, String, Proc] :checked_against
      #     Regex/String will be tested against the provided value
      #     Proc will have the content provided as the argument and must return a truthy value to be considered "valid"
      #
      def initialize(name, type, opts = {})
        template_name = (opts[:template] || name).to_sym
        opts = DEFAULTS[template_name].merge(opts) if DEFAULTS.key?(template_name)

        @name = name
        @type = type.to_sym
        @discord_type = Discordrb::Interactions::OptionBuilder::TYPES[@type]
        @display_name = (opts[:display_name] || name).to_sym
        @command_class = opts[:command_class]
        @command_name = command_class.command_name.to_sym

        @required = !!opts[:required]
        @default_value = opts[:default]
        @preserve_case = !!opts[:preserve_case]
        @type_caster = opts[:type_caster]
        @modifier = opts[:modifier] || ->(_) {}
        @validator = opts[:checked_against]

        @options = {required: @required}
        @options[:min_value] = opts[:min_value] if opts[:min_value]
        @options[:max_value] = opts[:max_value] if opts[:max_value]

        # I prefer {value: "Display Name"}, Discord/rb wants it to be {"Display Name": "value"}
        if opts[:choices]
          @options[:choices] = opts[:choices].map { |k, v| [v.to_s, k.to_s] }.to_h
        end

        @description = load_locale_or_provided(opts[:description], "description")
        @description_extra = load_locale_or_provided(opts[:description_extra], "description_extra").presence

        @optional_text =
          if (text = opts[:optional_text].presence)
            load_locale_or_provided(text, "optional_text")
          elsif optional?
            text = "This argument is optional#{default_value? ? "" : "."}"
            text += " and it defaults to `#{default_value}`." if default_value?
            text
          end

        check_for_valid_configuration!
      end

      def transform_and_validate!(input, command)
        raise ArgumentError, "Invalid command argument" unless command.is_a?(ApplicationCommand)

        context = ArgumentContext.new(content: format(input))

        # Arguments can opt to modify the parsed value (this is how auto-fill works)
        command.instance_exec(context, &modifier) if modifier?

        # Now that potential modification is done, pull the content back out
        content = context.content

        debug!(
          argument: to_h.except(:description, :description_extra),
          input: input,
          output: {
            type: content.class.name,
            content: content
          }
        )

        check_for_valid_content!(command, content)

        content
      end

      def preserve_case?
        @preserve_case
      end

      def modifier?
        modifier&.respond_to?(:call)
      end

      def default_value?
        !!@default_value
      end

      def required?
        @required
      end

      def optional?
        !required?
      end

      def optional_text?
        optional_text.present?
      end

      def to_s
        if display_name.present?
          display_name.to_s
        else
          name.to_s
        end
      end

      def help_documentation
        output = ["**`#{self}`**", description]
        output << "#{description_extra}." if description_extra.presence
        output << "**Note:** #{optional_text}" if optional_text?
        output.join("\n")
      end

      def to_h
        {
          name: name,
          command_name: command_name,
          display_name: display_name,
          description: description,
          description_extra: description_extra,
          optional_text: optional_text,
          default_value: default_value,
          cast_type: cast_type,
          modifier: modifier,
          validator: validator
        }
      end

      private

      def load_locale_or_provided(path, suffix)
        locale_path = path.presence || "commands.#{command_name}.arguments.#{name}.#{suffix}"
        localized = I18n.translate(locale_path, default: "")

        # Allows not having to provide an I18n path as the description
        if (localized.blank? || localized.starts_with?("translation missing")) && path.present?
          path
        else
          localized
        end
      end

      def format(value)
        value =
          if value.present?
            preserve_case? ? value.strip : value.downcase.strip
          elsif default_value?
            default
          else
            value
          end

        cast_to_type(value)
      end

      def cast_to_type(value)
        return if value.nil?

        case type
        when :json
          ESM::JSON.parse(value)
        when :symbol
          value.to_sym
        else
          value
        end
      rescue
        value
      end

      def check_for_valid_content!(command, content)
        return if content.nil? && required?
        return unless validator

        success =
          case validator
          when Regexp, String
            content.match?(validator)
          when Proc
            command.instance_exec(content, &validator)
          end

        return if success

        raise ESM::Exception::InvalidArgument, self
      end

      def check_for_valid_configuration!
        # choices must be hash
        # choice values must be string
        if options.key?(:choices)
          if !options[:choices].is_a?(Hash)
            raise ArgumentError, "#{command_class}:argument.#{name} - choices must be a hash"
          end

          if options[:choices].values.any? { |v| !v.is_a?(String) }
            raise ArgumentError, "#{command_class}:argument.#{name} - choices cannot contain non-string values"
          end
        end

        # min/max values can only be with integer/number type
        if options.key?(:min_value) || options.key?(:max_value)
          if [:integer, :number].exclude?(type)
            raise ArgumentError, "#{command_class}:argument.#{name} - min/max values can only be used with integer or number types"
          end
        end

        if description.length > 100
          raise ArgumentError, "#{command_class}:argument.#{name} - description cannot be longer than 100 characters"
        end

        if description.length < 1
          raise ArgumentError, "#{command_class}:argument.#{name} - description must be at least 1 character long"
        end
      end
    end
  end
end
