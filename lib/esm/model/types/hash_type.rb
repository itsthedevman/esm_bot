# frozen_string_literal: true

class HashType < ActiveRecord::Type::Json
  def deserialize(value)
    hash = super
    return hash unless hash.is_a?(Hash)

    hash.deep_symbolize_keys
  end
end
