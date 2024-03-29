# frozen_string_literal: true

module ESM
  class User
    attr_accessor :guild_type, :role_id, :connected

    def deregister!
      update!(steam_uid: nil)
    end
  end
end
