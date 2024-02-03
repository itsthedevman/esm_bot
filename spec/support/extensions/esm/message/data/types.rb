# frozen_string_literal: true

module ESM
  class Message
    class Data
      module Types
        TYPES_MAPPING = TYPES_MAPPING.merge(
          data_test: {
            foo: :string
          },
          test_mapping: {
            array: :array,
            date_time: :date_time,
            date: :date,
            hash_map: :hash_map,
            integer: :integer,
            rhash: :hash,
            string: :string
          },
          test_extras: {
            subtype: {
              type: :array,
              subtype: :hash_map
            },
            optional: {
              type: :integer,
              optional: true
            }
          }
        )
      end
    end
  end
end
