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
              ESM.redis.hset("#{server_id}", "#{key}", val.to_s)
            end

            def #{key}
              @#{key} ||= ESM.redis.hget("#{server_id}", "#{key}")
            end
          METHODS
        end
      end
    end
  end
end
