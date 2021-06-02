# frozen_string_literal: true

class OpenStruct
  attr_reader :table

  def blank?
    self.to_h.blank?
  end

  def to_h
    self.marshal_dump.transform_values do |value|
      case value
      when OpenStruct
        value.to_h
      when ActiveSupport::Duration
        value.parts
      else
        value
      end
    end
  end

  def each(&block)
    return self if !block_given?

    # Loop over each key and call the passed block with the key and the original value
    # This means nested OpenStructs stay as OpenStructs
    self.to_h.each_keys do |key|
      block.call(key.to_s, self[key])
    end

    self
  end

  def map(&block)
    return [] if !block_given?

    # Loop over each key and call the passed block with the key and the original value
    # This means nested OpenStructs stay as OpenStructs
    self.to_h.keys.map do |key|
      block.call(key.to_s, self[key])
    end
  end
end
