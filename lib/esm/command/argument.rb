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
          checked_against: ->(content) { ESM::Command.include?(content) },
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
          modifier: lambda do |content|
            if content.present?
              # User alias
              if (id_alias = current_user.id_aliases.find_community_alias(content))
                content = id_alias.community.community_id
              end

              return content
            end

            # content == nil, attempt to find and use a default
            if current_user.id_defaults.community_id
              # User default
              current_user.id_defaults.community.community_id
            elsif current_channel.text?
              # Community autofill
              current_community.community_id
            end
          end
        },

        # Optional: UserDefault/CommunityDefault can be used. It will be validated so it is "semi-required"
        server_id: {
          checked_against: ESM::Regex::SERVER_ID,
          description_extra: "commands.arguments.server_id.description_extra",
          description: "commands.arguments.server_id.description",
          optional_text: "commands.arguments.server_id.optional_text",
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
              # Community Defaults

              # Channel default
              channel_default = current_community.id_defaults.for_channel(current_channel)
              return channel_default.server.server_id if channel_default&.server_id

              # Global default
              global_default = current_community.id_defaults.global
              return global_default.server.server_id if global_default&.server_id
            elsif current_user.id_defaults.server_id
              # User Default
              current_user.id_defaults.server.server_id
            end

            # this is nil by this point
          end
        }
      }.freeze

      # @!visibility private
      class ArgumentContext < Struct.new(:content, keyword_init: true)
      end
      private_constant :ArgumentContext

      attr_reader :name, :type, :discord_type,
        :display_name, :command_class, :command_name,
        :default_value, :modifier,
        :description, :description_extra, :optional_text,
        :options, :checked_against

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
        @modifier = opts[:modifier]
        @checked_against = opts[:checked_against]

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

        sanitized_content =
          if input.is_a?(String)
            preserve_case? ? input.strip : input.downcase.strip
          elsif input.nil? && default_value?
            default_value
          else
            input
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
          modifier: modifier,
          checked_against: checked_against
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

      def check_for_valid_content!(command, content)
        validator, validate_if =
          if checked_against.is_a?(Hash)
            [checked_against[:validator], checked_against[:if]]
          else
            [checked_against, nil]
          end

        return unless validator

        validate_if = ->(argument, content) { !(argument.optional? && content.blank?) } if validate_if.nil?
        return unless command.instance_exec(self, content, &validate_if)

        success =
          case validator
          when Regexp, String
            content.to_s.match?(validator)
          when Proc
            command.instance_exec(content, &validator)
          when Array
            validator.include?(content)
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
