# frozen_string_literal: true

module ESM
  module Command
    class Argument
      DEFAULTS = {
        target: {regex: ESM::Regex::TARGET, description: "commands.arguments.target"},
        territory_id: {regex: ESM::Regex::TERRITORY_ID, description: "commands.arguments.territory_id"},
        community_id: {
          regex: ESM::Regex::COMMUNITY_ID,
          description: "commands.arguments.community_id",
          preserve: true,
          default: nil,
          optional_text: "This argument may be excluded if a community is set as a default for you, or the Discord community if you are using this command in a text channel",
          modifier: lambda do |argument|
            if argument.content.present?
              # User alias
              if (id_alias = current_user.id_aliases.find_community_alias(argument.content))
                argument.content = id_alias.community.community_id
                return
              end

              return # Keep whatever was given - it'll be validated later
            end

            # Nothing was provided for this argument
            # Attempt to find and use a default

            # User default
            if current_user.id_defaults.community_id
              argument.content = current_user.id_defaults.community.community_id
              return
            end

            # Community autofill
            if current_channel.text?
              argument.content = current_community.community_id
            end

            # Nothing was provided and there was no default - it'll be validated later
          end
        },
        server_id: {
          regex: ESM::Regex::SERVER_ID_OPTIONAL_COMMUNITY,
          description: "commands.arguments.server_id",
          preserve: true,
          default: nil,
          optional_text: "This argument may be excluded if a server is set as a default for you, or the Discord community if you are using this command in a text channel",
          modifier: lambda do |argument|
            if argument.content.present?
              # User provided - Starts with a community ID
              return if argument.content.match("#{ESM::Regex::COMMUNITY_ID_OPTIONAL.source}_")

              # User alias
              if (id_alias = current_user.id_aliases.find_server_alias(argument.content))
                argument.content = id_alias.server.server_id
                return
              end

              # Community autofill
              if current_channel.text? && current_community.servers.by_server_id_fuzzy(argument.content).any?
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

            # Nothing was provided and there was no default - it'll be validated later
          end
        }
      }.freeze

      attr_reader :name, :type, :display_name, :command_name,
        :default_value, :cast_type, :modifier,
        :description, :description_long, :optional_text,
        :options, :validator

      #
      # A configurable representation of a command argument
      #
      # @param name [Symbol, String] The argument's name
      # @param type [Symbol, String] Optional. The argument's type (directly linked to Discord). Default: :string
      # @param opts [Hash] Options to configure the argument
      # @option opts [Boolean] :required Optional. Sets if the argument MUST be provided by the user. Default: true
      # @option opts [Symbol, String, nil] :template The name of an entry in DEFAULTS to use as a foundation
      #     in which these `opts` are merged into. Useful for having an argument that acts like another argument
      # @option opts [String] :description This argument's description, in less than 120 characters.
      #     Note: Providing this option is optional, however, all arguments MUST have a non-blank description
      #     This description is used in Discord when viewing the argument.
      #     This value defaults to the value located at the locale path:
      #         commands.<command_name>.arguments.<argument_name>.desc_short
      # @option opts [String] :description_long This argument's description, but more descriptive
      #     Note: Providing this option is optional, however, this argument MUST have a non-blank description
      #     This description is used in the help documentation with the help command and on the website
      #     This value defaults to the value located at the locale path:
      #         commands.<command_name>.arguments.<argument_name>.desc_long
      # @option opts [String] :optional_text Optional. Allows for overriding the "this argument is optional" text
      #     in the help documentation. This argument must be optional for this to be used.
      #     This is used in the help documentation with the help command and on the website
      #     This value defaults to the value located at the locale path:
      #         commands.<command_name>.arguments.<argument_name>.optional_text
      # @option opts [Symbol, String] :display_name Optional. Allows overwriting the display name of the argument
      #     without changing how the argument is referenced in code
      # @option opts [Object] :default Optional. The default value if this argument is not required. Default: nil
      # @option opts [Boolean] :preserve_case Optional. Controls if this argument's value should be converted to
      #     lowercase or not. Default: false
      # @option opts [Symbol, Proc] :type_caster Optional. Performs extra casting once the value is received from Discord
      #     If the value is a Symbol, it will be be checked against the available options.
      #     If the value is a Proc, it will be called and the raw value passed in
      #     Valid options: :json, :symbol
      # @option opts [Proc] :modifier Optional. A block of code used to modify this argument's value before validation
      # @option opts [Array<String>] :choices Optional. A list of choices the user can pick for this argument
      # @option opts [Integer] :min_value If type is integer/number, this is the minimum value that can be selected
      # @option opts [Integer] :max_value If type is integer/number, this is the maximum value that can be selected
      # @option opts [nil, Regex] :validate_with If provided, this will be tested against the input.
      #
      def initialize(name, type, opts = {})
        template_name = (opts[:template] || name).to_sym
        opts = DEFAULTS[template_name].merge(opts) if DEFAULTS.key?(template_name)

        @name = name
        @type = type
        @display_name = (opts[:display_name] || name).to_sym
        @command_name = opts[:command_name].to_sym

        @required = !!opts[:required]
        @default_value = opts[:default]
        @preserve_case = !!opts[:preserve_case]
        @type_caster = opts[:type_caster]
        @modifier = opts[:modifier] || ->(_) {}
        @validator = opts[:validate_with]

        @options = {}
        @options[:choices] = opts[:choices] if opts[:choices]
        @options[:min_value] = opts[:min_value] if opts[:min_value]
        @options[:max_value] = opts[:max_value] if opts[:max_value]

        description = load_locale_or_provided(opts[:description], "description")
        @description = description.truncate(99) # Discord req: Must be less than 100 characters
        @description_long = load_locale_or_provided(opts[:description_long], "description_long").presence || description

        @optional_text =
          if (text = opts[:optional_text].presence)
            load_locale_or_provided(text, "optional_text")
          elsif optional?
            text = "This argument is optional#{default_value? ? "" : "."}"
            text += " and it defaults to `#{default_value}`." if default_value?
            text
          end
      end

      def validate!(input, command)
        content = format(input)

        # Arguments can opt to modify the parsed value (this is how auto-fill works)
        command.instance_exec(self, &modifier) if modifier?

        debug!(
          argument: to_h.except(:description, :description_long),
          input: input,
          output: {
            type: content.class.name,
            content: content
          }
        )

        check_for_valid_content!(content)

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

      def optional!
        @required = false
      end

      def optional_text?
        optional_text.present?
      end

      def to_s
        name =
          if display_name.present?
            display_name.to_s
          else
            self.name.to_s
          end

        "<#{"?" if optional?}#{name}>"
      end

      def help_documentation(command = nil)
        output = ["**`#{self}`**"]

        output << "#{description_long}." if description_long.presence

        output << "**Note:** #{optional_text}" if optional_text?
        output.join("\n")
      end

      def to_h
        {
          name: name,
          command_name: command_name,
          display_name: display_name,
          description: description,
          description_long: description_long,
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

      def check_for_valid_content!(content)
        return unless validator
        return if content.match?(validator)

        raise ESM::Exception::InvalidArgument, self
      end
    end
  end
end
