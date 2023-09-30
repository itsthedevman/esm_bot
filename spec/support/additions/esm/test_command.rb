# frozen_string_literal: true

module ESM
  class TestCommand < ApplicationCommand
    def self.argument(name, type = nil, **opts)
      super(name, type, **opts.merge(description: "Defaulted testing description"))
    end
  end
end
