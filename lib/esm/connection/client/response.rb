# frozen_string_literal: true

module ESM
  module Connection
    class Client
      class Response < Data.define(:id, :type, :content)
        TYPES = Request::TYPES

        def initialize(**data)
          type = TYPES[data[:t]]
          raise ArgumentError, "Invalid type #{data[:i]}" if type.nil?

          super(id: data[:i]&.delete("-"), type: type, content: data[:c].pack("U*"))
        end
      end
    end
  end
end
