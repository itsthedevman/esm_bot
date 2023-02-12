# frozen_string_literal: true

# The main driver for all of ESM's commands. This class is synomysis with ActiveRecord::Base in that all commands inherit
# from this class and this class gives access to a lot of the core functionality.
module ESM
  module Command
    class Base
      # These commands have a V1 variant
      V1_COMMANDS = [
        # :add,
        # :demote,
        # :gamble,
        # :info,
        # :logs,
        # :me,
        # :pay,
        # :player,
        # :promote,
        # :remove,
        # :reset,
        # :restore,
        :reward,
        # :server_territories,
        # :set_id,
        :sqf
        # :stuck,
        # :territories,
        # :upgrade
      ].freeze

      include Definition
      include Metadata
      include Helpers
      include Lifecycle
    end
  end
end
