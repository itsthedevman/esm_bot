# frozen_string_literal: true

module ESM
  class Message
    class Metadata < Struct.new(:player, :target, :server_id)
      def initialize(player: nil, target: nil, server_id: nil)
        player = Player.from(player) if player
        target = Target.from(target) if target

        super(player:, target:, server_id:)
      end

      def to_h
        super.tap do |hash|
          hash.transform_values!(&:to_h)
          hash.delete_if { |_k, v| v.blank? }
        end
      end
    end
  end
end
