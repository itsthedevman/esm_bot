# frozen_string_literal: true

module ESM
  module Connection
    class MessageOverseer
      attr_reader :mailbox if ESM.env.test?
    end
  end
end
