# frozen_string_literal: true

class SpecButtonEvent
  Interaction = Data.define(:button)
  Button = Data.define(:custom_id)

  attr_reader :interaction

  def initialize(custom_id: "")
    @interaction = Interaction.new(button: Button.new(custom_id:))
  end

  def defer_update
    true
  end
end
