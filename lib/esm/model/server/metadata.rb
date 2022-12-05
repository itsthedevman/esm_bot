# frozen_string_literal: true

module ESM
  class Server
    class Metadata
      KEYS = [
        "vg_enabled", "vg_max_sizes"
      ].freeze

      def initialize(server_id)
        KEYS.each do |key|
          class_eval <<-METHODS, __FILE__, __LINE__ + 1
            def #{key}=(val)
              @#{key} = val.to_s
              ESM.redis.hset("metadata_#{server_id}", "#{key}", @#{key})
              ESM.redis.expire("metadata_#{server_id}", 604_800)
            end

            def #{key}
              @#{key} ||= lambda do
                ESM.redis.hget("metadata_#{server_id}", "#{key}")
              end.call
            end
          METHODS
        end
      end
    end
  end
end
