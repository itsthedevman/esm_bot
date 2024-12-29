# frozen_string_literal: true

module ESM
  class Bot
    attr_reader :delivery_overseer

    def add_await!(type, attributes = {})
      case ESM::Test.response.message.content
      when true
        SpecButtonEvent.new(custom_id: "-true")
      when false
        SpecButtonEvent.new(custom_id: "-false")
      end
    end
  end
end
