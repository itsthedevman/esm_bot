# frozen_string_literal: true

module ESM
  class Message
    class Metadata < Data
      TYPES_MAPPING = TYPES_MAPPING.merge(metadata_test: {bar: :string}).freeze
    end
  end
end
