# frozen_string_literal: true

module ESM
  module Connection
    class Client
      class Request < Data.define(:id, :type, :content)
        # These numbers MUST match the associated ServerRequestType enum value in esm_arma/src/esm/src/bot.rs
        TYPES = {
          0 => :noop,
          1 => :error,
          2 => :identification,
          3 => :handshake,
          4 => :initialize,
          5 => :message
        }.freeze

        delegate :to_json, to: :to_h

        def initialize(type:, id: nil, content: nil)
          raise ArgumentError, "Invalid type #{type}" unless TYPES.value?(type.to_sym)

          content =
            case content
            when NilClass
              []
            when Array
              content
            when Symbol
              content.to_s.bytes
            when ->(c) { c.respond_to?(:bytes) }
              content.bytes
            else
              raise ArgumentError, "Content must be a Symbol, Array, or must respond to #bytes"
            end

          id ||= SecureRandom.uuid.delete("-")

          super(id: id, type: type, content: content)
        end

        def to_h
          super.tap do |hash|
            hash[:type] = TYPES.key(hash[:type])
            hash.transform_keys! { |k| k.to_s.first }
          end
        end
      end
    end
  end
end
