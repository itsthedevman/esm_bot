# frozen_string_literal: true

class ImmutableStruct < Data
  def self.name
    "ImmutableStruct"
  end

  alias_method :to_hash, :to_h
  alias_method :values, :deconstruct

  def ==(other)
    to_h == other&.to_h
  end

  # Act like ostruct and return nil if the method isn't defined
  def method_missing(method_name, *, &block)
    send(method_name, *, &block) if self.class.method_defined?(method_name)
  end

  def respond_to_missing?(_method_name, _include_private = false)
    true
  end
end
