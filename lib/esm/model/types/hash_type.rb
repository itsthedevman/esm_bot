# frozen_string_literal: true

class HashType < ActiveRecord::Type::Json
  def deserialize(value)
    deep_symbolize_keys(super)
  end

  private

  def deep_symbolize_keys(value)
    case value
    when Hash
      value.deep_symbolize_keys
    when Array
      value.map { |v| deep_symbolize_keys(v) }
    else
      value
    end
  end
end
