# frozen_string_literal: true

module ESM
  class Xm8Notification
    class Custom < Xm8Notification
      def valid?
        content.to_h.slice(*Embed::ATTRIBUTES).size > 0
      end
    end
  end
end
