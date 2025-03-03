# frozen_string_literal: true

class String
  NUMBER_HELPER = ActiveSupport::NumberHelper

  def steam_uid?
    ESM::Regex::STEAM_UID_ONLY.match?(self)
  end

  def discord_id?
    ESM::Regex::DISCORD_ID_ONLY.match?(self)
  end

  def to_ostruct
    ESM::JSON.parse(self, as_ostruct: true)
  end

  delegate :to_struct, :to_istruct, to: :to_h

  def to_h
    ESM::JSON.parse(self)
  end
  alias_method :to_a, :to_h

  def to_deep_h
    transformer = lambda do |object|
      case object
      when Array
        object.map { |v| transformer.call(v) }
      when String
        result = object.to_deep_h

        case result
        when Array, Hash
          transformer.call(result)
        else
          object
        end
      when Hash
        object.transform_values { |v| transformer.call(v) }
      else
        object
      end
    end

    transformer.call(to_h)
  end

  def to_poptab
    # Convert from Scientific notation.
    # Arma automatically converts to scientific notation if the value is greater than 2mil
    value = "%f" % self
    value = NUMBER_HELPER.number_to_currency(value, unit: I18n.t(:poptabs), format: "%n %u", precision: 0)

    # 1 will convert to "1 poptabs", this makes it "1 poptab"
    if self == "1"
      value.gsub(I18n.t(:poptabs), I18n.t(:poptab))
    else
      value
    end
  end

  def to_readable(precision: 0)
    NUMBER_HELPER.number_to_currency("%f" % self, format: "%n", precision: precision)
  end

  def to_delimited
    NUMBER_HELPER.number_to_delimited(self)
  end

  # Extending active support classify to allow leaving the s on the end
  def classify(keep_plural: false)
    if keep_plural
      sub(/.*\./, "").camelize
    else
      ActiveSupport::Inflector.classify(self)
    end
  end

  alias_method :quoted, :to_json
end
