# frozen_string_literal: true

class SpecDiscordMessage < Struct.new(:content)
  def initialize(content)
    super(content:)
  end

  def edit(content, ...)
    self.content = content
  end
end
