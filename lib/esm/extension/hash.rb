# frozen_string_literal: true

class Hash
  def to_ostruct
    self.to_json.to_ostruct
  end

  def format(join_with: "", &block)
    self.map(&block).join(join_with)
  end
end
