# frozen_string_literal: true

module ESM
  class Message
    class Metadata < Data
      TYPES_MAPPING = {
        empty: {},
        command: {
          player: :hash_map,
          target: {
            type: :hash_map,
            optional: true
          }
        }
      }.freeze
    end
  end
end
