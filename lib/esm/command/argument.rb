# frozen_string_literal: true

module ESM
  module Command
    class Argument
      DEFAULTS = {
        target: {regex: ESM::Regex::TARGET},
        territory_id: {regex: ESM::Regex::TERRITORY_ID},
        community_id: {
          regex: ESM::Regex::COMMUNITY_ID,
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

      attr_reader :name, :parser, :opts
      attr_accessor :content

      def initialize(name, opts = {})
        @name = name
        @opts = load_options(opts)
        @content = nil
      end

      def store(input, command)
        @content = format(input)

        # Arguments can opt to modify the parsed value (this is how auto-fill works)
        command.instance_exec(self, &modifier) if modifier?

        debug!(
          argument: {
            name: name,
            display: to_s,
            regex: regex,
            default: default
          },
          input: input,
          output: {
            type: content.class.name,
            content: content
          }
        )
      end

      # All arguments are optional in regex.
      def regex
        @regex ||= "(?<#{name}>#{opts[:regex]&.source || ".+"})?"
      end

      def preserve_case?
        opts[:preserve] ||= false
      end

      def type
        opts[:type] ||= :string
      end

      def display_as
        opts[:display_as] ||= name.to_s
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

      def default?
        opts.key?(:default)
      end

      def required?
        !default?
      end

      # Only valid if argument has content and no default.
      # Allows content to be nil if not required
      def invalid?
        required? && content.nil?
      end

      def description(command = nil)
        description_path = opts[:description]

        # Defaults the description path to be commands.<name>.arguments.<name>
        if description_path.blank?
          description_path = "commands"
          description_path += ".#{command.name}" if command && !DEFAULTS.key?(name)
          description_path += ".arguments.#{name}"
        end

        # Call I18n with the name of the translation and pass the prefix into the translation by default
        description = I18n.send(
          :translate,
          description_path,
          prefix: command&.prefix || ESM.config.prefix || "!",
          default: ""
        )

        # Allows not having to provide an I18n path as the description
        if opts[:description].present? && (description.blank? || description.starts_with?("translation missing"))
          opts[:description]
        else
          description
        end
      end

      def optional_text
        return if required?
        # Check for the key so this can be set back to nil
        return opts[:optional_text] if opts.key?(:optional_text)

        has_default = !default.nil?
        opts[:optional_text] = "This argument is optional#{has_default ? "" : "."}"
        opts[:optional_text] += " and it defaults to `#{default}`." if has_default
        opts[:optional_text]
      end

      def optional_text?
        optional_text.present?
      end

      def to_s
        name =
          if display_as.present?
            display_as.to_s
          else
            self.name.to_s
          end

        "<#{"?" if default?}#{name}>"
      end

      private

      def load_options(opts)
        argument_name = (opts[:template] || name).to_sym

        if DEFAULTS.key?(argument_name)
          DEFAULTS[argument_name].merge(opts)
        else
          opts
        end
      end

      def format(value)
        value =
          if value.present?
            preserve_case? ? value.strip : value.downcase.strip
          elsif default?
            default
          else
            value
          end

        cast_to_type(value)
      end

      def cast_to_type(value)
        case type
        when :integer
          value.to_i
        when :float
          value.to_f
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
    end
  end
end
