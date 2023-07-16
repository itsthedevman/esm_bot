# frozen_string_literal: true

module ESM
  #
  # A base class that allows for creating classes that can be asked questions.
  # Very similar to ActiveSupport::StringInquirer and ArrayInquirer, except stricter and faster
  #
  class Inquirer
    def initialize(*predicates)
      @predicates = predicates.map(&:to_sym)
      @predicates.each do |action|
        self.class.define_method("#{action}?") do
          !!instance_variable_get("@#{action}")
        end
      end
    end

    def set(*actions)
      actions = actions.map(&:to_sym)

      if (invalid_actions = actions - @predicates) && invalid_actions.any?
        raise ArgumentError, "#{invalid_actions} are not allowed as predicates for #{self.class.name}. Valid options: #{@predicates}"
      end

      actions.each do |action|
        instance_variable_set("@#{action}", true)
      end

      self
    end

    def unset(*actions)
      actions.map(&:to_sym).each do |action|
        next if @predicates.exclude(action)

        instance_variable_set("@#{action}", false)
      end

      self
    end

    def to_h
      @predicates.each_with_object({}) do |action, hash|
        hash[action] = public_send("#{action}?")
      end
    end

    def inspect
      "#<ESM::Inquirer:0x#{"%x" % (object_id << 1)} #{to_h.to_json}>"
    end
  end
end
