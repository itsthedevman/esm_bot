# frozen_string_literal: true

module ESM
  class Message
    class Metadata < ImmutableStruct.define(:player, :target, :server_id)
      def initialize(player: nil, target: nil, server_id: nil)
        new(player:, target:, server_id:)
      end
    end
  end
end
