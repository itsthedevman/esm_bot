# frozen_string_literal: true

module ESM
  module Connection
    class Client
      class Request < ImmutableStruct.define(:id, :type, :content)
        delegate :to_json, to: :to_h

        def initialize(id: nil, content: nil, **)
          id ||= SecureRandom.uuid.delete("-")[0..15]

          super(id: id, content: content, **)
        end

        def to_h
          super.transform_keys { |k| k.to_s.first }
        end
      end
    end
  end
end
