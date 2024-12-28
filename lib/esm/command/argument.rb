# frozen_string_literal: true

module ESM
  module Command
    class Argument
      #
      # Global default values for all argument
      # You may overwrite these in your argument definition
      #
      DEFAULT_TEMPLATE = {
        checked_against: :present?,
        checked_against_if: lambda do |argument, content|
          argument.required? || content.present?
        end
      }.freeze

      #
      # Global templates for any argument to use
      # These can be used by defining an argument with the same name,
      # or by providing the `:template` option during argument definition
      #
      TEMPLATES = {
        # Required: Majority of the time, this is needed.
        target: {
          checked_against: ESM::Regex::TARGET,
          description_extra: "commands.arguments.target.description_extra",
          description: "commands.arguments.target.description",
          required: true
        },

        # Required: Majority of the time, this is needed.
        command: {
          checked_against: ->(content) { ESM::Command.include?(content) },
          description: "commands.arguments.command.description",
          required: true
        },

        # Required: No functionality to "guess" this
        territory_id: {
          checked_against: ESM::Regex::TERRITORY_ID,
          description_extra: "commands.arguments.territory_id.description_extra",
          description: "commands.arguments.territory_id.description",
          required: true,
          placeholder: "territory"
        },

        # Optional in Discord: UserDefault/CommunityDefault can be used. It will be validated so it is "semi-required"
        # Required: In the bot
        community_id: {
          required: {discord: false, bot: true},
          checked_against: ESM::Regex::COMMUNITY_ID,
          description_extra: "commands.arguments.community_id.description_extra",
          description: "commands.arguments.community_id.description",
          optional_text: "commands.arguments.community_id.optional_text",
          placeholder: "community",
          modifier: lambda do |content|
            if content.present?
              # User alias
              if (id_alias = current_user.id_aliases.find_community_alias(content))
                content = id_alias.community.community_id
              end

              return content
            end

            # content == nil, attempt to find and use a default
            user_defaults = current_user.id_defaults
            return user_defaults.community.community_id if user_defaults.community_id

            # Community autofill
            return current_community.community_id if current_channel.text?

            nil
          end
        },

        # Optional in Discord: UserDefault/CommunityDefault can be used. It will be validated so it is "semi-required"
        # Required: In the bot
        server_id: {
          required: {discord: false, bot: true},
          checked_against: ESM::Regex::SERVER_ID,
          description_extra: "commands.arguments.server_id.description_extra",
          description: "commands.arguments.server_id.description",
          optional_text: "commands.arguments.server_id.optional_text",
          placeholder: "server",
          modifier: lambda do |content|
            if content.present?
              # User provided - Starts with a community ID
              return content if content.match("#{ESM::Regex::COMMUNITY_ID_OPTIONAL.source}_")

              # User alias
              if (id_alias = current_user.id_aliases.find_server_alias(content))
                return id_alias.server.server_id
              end

              # Community autofill
              if current_channel.text? && current_community.servers.by_server_id_fuzzy(content).any?
                return "#{current_community.community_id}_#{content}"
              end

              return content
            end

            # content == nil, attempt to find and use a default
            if current_channel.text?
              channel_default = current_community.id_defaults.for_channel(current_channel)
              return channel_default.server.server_id if channel_default&.server_id

              global_default = current_community.id_defaults.global
              return global_default.server.server_id if global_default&.server_id
            end

            if current_user.id_defaults.server_id
              user_defaults = current_user.id_defaults
              return user_defaults.server.server_id if user_defaults.server_id
            end

            nil
          end
        }
      }.freeze

      attr_reader :name, :type, :discord_type,
        :display_name, :command_class, :command_name,
        :default_value, :modifier, :placeholder,
        :description, :description_extra, :optional_text,
        :options, :checked_against, :checked_against_if

      #
      # A configurable representation of a command argument
      #
      # @param name [Symbol, String]
      #   The argument's name
      #
      # @param type [Symbol, String]
      #   The argument's type, mapped to Discord types
      #   via Discordrb::Interactions::OptionBuilder::TYPES.
      #   Optional. Default: :string
      #
      # @param opts [Hash] Options to configure the argument
      #   @option opts [Boolean, Hash] :required (false)
      #     Controls if the argument is required by Discord and/or the Bot.
      #     When Hash: {discord: Boolean, bot: Boolean} for fine-grained control
      #     When Boolean: Sets both discord and bot requirements
      #
      #   @option opts [Symbol, String] :template
      #     Name of a template from TEMPLATES or DEFAULT_TEMPLATE to inherit options from.
      #     Template options are merged with provided opts (opts take precedence)
      #
      #   @option opts [String] :description
      #     Discord-visible description (max 100 characters).
      #     Required either here or in locale path:
      #       commands.<command_name>.arguments.<argument_name>.description
      #
      #   @option opts [String] :description_extra
      #     Additional help text shown in documentation and website.
      #     Optional. Defaults to locale path:
      #       commands.<command_name>.arguments.<argument_name>.description_extra
      #
      #   @option opts [String] :optional_text
      #     Override text indicating argument is optional.
      #     Ignored if required: true
      #     Defaults to locale path:
      #       commands.<command_name>.arguments.<argument_name>.optional_text
      #
      #   @option opts [Symbol, String] :display_name
      #     User-facing argument name. Internal name remains unchanged.
      #
      #   @option opts [Object] :default
      #     Default value if argument is optional (ignored if required: true)
      #
      #   @option opts [Boolean] :preserve_case (false)
      #     If false, converts argument value to lowercase
      #
      #   @option opts [Proc] :modifier
      #     Transforms the argument value before validation
      #
      #   @option opts [Hash] :choices
      #     Valid choices as {value: "Display Name"}.
      #     Note: Internally converted to Discord format {"Display Name": "value"}
      #
      #   @option opts [Integer] :min_value
      #     Minimum allowed value for number/integer types
      #
      #   @option opts [Integer] :max_value
      #     Maximum allowed value for number/integer types
      #
      #   @option opts [Regex, String, Proc, Array] :checked_against
      #     Validation rules:
      #     - Regex/String: Value must match pattern
      #     - Proc: Must return truthy value
      #     - Array: Value must be included
      #     Invalid values trigger standard validation error handling
      #
      #   @option opts [Proc] :checked_against_if
      #     Controls when :checked_against validation occurs.
      #     Must return truthy value to trigger validation
      #
      #   @option opts [String, Symbol] :placeholder
      #     Placeholder text shown in usage examples.
      #     Defaults to argument name
      #
      # @example Basic required string argument
      #   argument :username, required: true
      #
      # @example Number with range and custom validation
      #   argument :count, :integer,
      #     min_value: 0,
      #     max_value: 100,
      #     checked_against: ->(val) { val.even? }
      #
      # @example Using a template with overrides
      #   argument :territory, template: :territory_id,
      #     description: "Custom description"
      #
      def initialize(name, type = nil, opts = {})
        template_name = (opts[:template] || name).to_sym

        # Precedence:
        #   opts -> template -> default template
        opts = DEFAULT_TEMPLATE.merge(TEMPLATES[template_name] || {}).merge(opts)

        @name = name
        @type = type ? type.to_sym : :string

        @discord_type = Discordrb::Interactions::OptionBuilder::TYPES[
          (type == :float) ? :number : @type
        ]

        @display_name = (opts[:display_name] || name).to_sym
        @command_class = opts[:command_class]
        @command_name = command_class.command_name.to_sym

        @default_value = opts[:default]
        @preserve_case = !!opts[:preserve_case]
        @modifier = opts[:modifier]
        @checked_against = opts[:checked_against]
        @checked_against_if = opts[:checked_against_if]
        @placeholder = opts[:placeholder].presence || name

        if opts[:required].is_a?(Hash)
          @required_by_discord = !!opts.dig(:required, :discord)
          @required_by_bot = !!opts.dig(:required, :bot)
        else
          required = !!opts[:required]
          @required_by_discord = required
          @required_by_bot = required
        end

        @options = {required: @required_by_discord}
        @options[:min_value] = opts[:min_value] if opts[:min_value]
        @options[:max_value] = opts[:max_value] if opts[:max_value]

        # I prefer {value: "Display Name"}, Discord/rb wants it to be {"Display Name": "value"}
        if opts[:choices]
          @options[:choices] = opts[:choices].map { |k, v| [v.to_s, k.to_s] }.to_h
        end

        @description = load_locale_or_provided(opts[:description], "description")
        @description_extra = load_locale_or_provided(opts[:description_extra], "description_extra").presence
        @optional_text = load_optional_text(opts[:optional_text])

        check_for_valid_configuration!
      end

      def transform_and_validate!(input, command)
        raise ArgumentError, "Invalid command argument" unless command.is_a?(ApplicationCommand)

        input_present = input.present?
        input = default_value if !input_present && default_value?

        casted_content = cast_to_type(input)

        sanitized_content =
          if casted_content.is_a?(String) && input_present
            preserve_case? ? casted_content.strip : casted_content.downcase.strip
          else
            casted_content
          end

        content =
          if modifier?
            command.instance_exec(sanitized_content, &modifier)
          else
            sanitized_content
          end

        debug!(
          argument: to_h.except(:description, :description_extra, :optional_text),
          input: input,
          before: {
            type: sanitized_content.class.name,
            content: sanitized_content
          },
          after: {
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
        !!modifier&.respond_to?(:call)
      end

      def default_value?
        !!@default_value
      end

      def required_by_bot?
        @required_by_bot
      end

      def required_by_discord?
        @required_by_discord
      end

      def required?
        required_by_bot? || required_by_discord?
      end

      def optional?
        !required_by_bot? && !required_by_discord?
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
        output = ["**`#{self}:`**", description]
        output << "#{description_extra}." if description_extra.presence
        output << "**Note:** #{optional_text}" if optional_text?
        output.join("\n")
      end

      def to_h
        {
          name:,
          type:,
          command_name:,
          display_name:,
          description:,
          description_extra:,
          optional_text:,
          default_value:,
          modifier:,
          checked_against:,
          preserve_case: preserve_case?,
          discord: @options,
          bot: {
            required: @required_by_bot
          }
        }
      end

      private

      def load_locale_or_provided(path, suffix)
        return "" if path == "" # Allows skipping this process. Validation will still fire

        locale_path = path.presence || "commands.#{command_name}.arguments.#{name}.#{suffix}"
        localized = I18n.translate(locale_path, default: "")

        # Allows not having to provide an I18n path as the description
        if (localized.blank? || localized.starts_with?("translation missing")) && path.present?
          path
        else
          localized
        end
      end

      def load_optional_text(text_or_path)
        return "" unless optional?

        if (text = load_locale_or_provided(text_or_path, "optional_text"))
          return text if text.present?
        end

        text = "This argument is optional#{default_value? ? "" : "."}"
        text += " and it defaults to `#{default_value}`." if default_value?
        text
      end

      def check_for_valid_content!(command, content)
        return if checked_against_if.nil? || checked_against.nil?
        return unless successful_checked_against_if?(command, content)
        return if successful_checked_against?(command, content)

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

      def successful_checked_against_if?(command, content)
        case checked_against_if
        when Proc
          !!command.instance_exec(self, content, &checked_against_if)
        when TrueClass, FalseClass
          checked_against_if
        end
      end

      def successful_checked_against?(command, content)
        case checked_against
        when Regexp, String
          content.to_s.match?(checked_against)
        when Proc
          !!command.instance_exec(content, &checked_against)
        when Array
          checked_against.include?(content)
        when Symbol
          !!content.public_send(checked_against)
        end
      end

      def cast_to_type(value)
        case type
        when :integer
          return value if value.is_a?(Integer)

          value.to_i
        when :float
          return value if value.is_a?(Float)

          value.to_f
        when :boolean
          return value if value.is_a?(TrueClass) || value.is_a?(FalseClass)

          value == "true"
        else
          value
        end
      end
    end
  end
end
