# frozen_string_literal: true

module ESM
  class Message
    private

    alias_method :default_default_on_error, :default_on_error

    # Makes it easier to see when a command fails in specs
    def default_on_error(incoming_message)
      default_default_on_error(incoming_message)

      errors = (self.errors || []) + (incoming_message&.errors || [])
      errors.map! { |e| e.to_s(self) }.uniq!

      raise errors.to_sentence
    end
  end
end