# frozen_string_literal: true

module ESM
  module Command
    class Base
      attr_writer :limit_to, :requires, :event
    end
  end
end