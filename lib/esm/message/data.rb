# frozen_string_literal: true

module ESM
  class Message
    class Data
      include Types

      attr_reader :type, :content

      def initialize(type = :empty, content = nil)
        @type = type.to_sym
        @original_content = {}
        @content = {}
        return if type == :empty

        content =
          case content
          when OpenStruct
            content.table
          when Struct, ImmutableStruct
            content.to_h
          else
            content
          end

        return unless content.is_a?(Hash)

        content = sanitize_inbound_content(content)
        @original_content = content
        @content = content.to_istruct
      end

      def to_h(for_arma: false)
        hash = {type: type}

        # This blocks the content key from being added to the hash
        #   which in turn keeps it from being included in the JSON that is sent to the server
        #   Bonus: Handles invalid data
        if !@original_content.is_a?(Hash) ||
            (for_arma && type == :empty) ||
            (for_arma && @original_content.blank?)
          return hash
        end

        hash[:content] = @original_content.transform_values { |v| convert_into_arma(v) }
        hash
      end

      private

      def retrieve_type_data(type)
        type_data = TYPES[type]
        if type_data.nil?
          raise ESM::Exception::InvalidMessage, "\"#{type}\" was not defined in ESM::Message::Data::TYPES"
        end

        type_data
      end

      # Sanitizes the provided content in accordance to the data defined in config/mapping.yml
      # Sanitize also ensures the order of the content when exporting
      # @see config/mapping.yml for more information
      def sanitize_inbound_content(inbound_content)
        inbound_content.deep_symbolize_keys!
        types_mapping = TYPES_MAPPING[@type]

        # Catches if TYPES_MAPPING does not have type defined
        if types_mapping.nil?
          raise ESM::Exception::InvalidMessage, "Failed to find #{self.class.name} type \"#{@type}\" in \"config/message/*_types.yml\""
        end

        types_mapping.each_with_object({}) do |(attribute_name, attribute_hash), output|
          # Check for missing required attributes
          if attribute_hash[:optional].blank? && !inbound_content.key?(attribute_name)
            raise ESM::Exception::InvalidMessage,
              "Missing required key \"#{attribute_name}\" for #{self.class.name} type \"#{@type}\""
          end

          attribute_hash[:attribute_name] = attribute_name

          # Not all items will be converted, it depends on the configs
          output[attribute_name] = convert_into_ruby(inbound_content[attribute_name], **attribute_hash)
        end
      end

      def convert_into_ruby(inbound_value, **attribute_hash)
        type = (attribute_hash[:type] || :any).to_sym

        # Handle if it can be nil or not
        can_be_nil = type == :any || attribute_hash[:optional]
        if inbound_value.nil? && !can_be_nil
          raise ESM::Exception::InvalidMessage,
            "Missing attribute \"#{attribute_hash[:attribute_name]}\" for \"#{@type}\""
        end

        # This contains the conversion data
        type_data = retrieve_type_data(type)

        optional = attribute_hash[:optional] || false
        valid_classes = type_data[:valid_classes] || []

        # Check if converting is needed
        if (optional && inbound_value.nil?) || valid_classes.any? { |c| inbound_value.is_a?(c) }
          return inbound_value
        end

        into_ruby = type_data[:into_ruby] || ->(value) { value }
        result = into_ruby.call(inbound_value)

        # Subtype only supports Array (as of right now)
        subtype = attribute_hash[:subtype]
        return result unless type == :array && subtype&.key?(:type)

        subtype[:attribute_name] = attribute_hash[:attribute_name]
        result.map { |v| convert_into_ruby(v, **subtype) }
      end

      def convert_into_arma(inbound_value)
        convert_to_type = RUBY_TYPE_LOOKUP[inbound_value.class] || :any
        type_data = retrieve_type_data(convert_to_type)

        into_arma = type_data[:into_arma] || ->(value) { value }
        instance_exec(inbound_value, &into_arma)
      end
    end
  end
end
