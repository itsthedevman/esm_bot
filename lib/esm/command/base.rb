# frozen_string_literal: true

# The main driver for all of ESM's commands. This class is synomysis with ActiveRecord::Base in that all commands inherit
# from this class and this class gives access to a lot of the core functionality.
module ESM
  module Command
    class Base
      include Checks
      include Definition
      include Helpers
      include Lifecycle
      include Metadata
      include Migration
      include Permissions
    end
  end
end
