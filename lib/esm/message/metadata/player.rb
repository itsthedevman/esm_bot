# frozen_string_literal: true

module ESM
  class Message
    class Metadata
      class Player < ImmutableStruct.define(:discord_id, :discord_username, :discord_mention, :steam_uid)
        def initialize(discord_id: nil, discord_username: nil, discord_mention: nil, steam_uid: nil)
          new(discord_id:, discord_username:, discord_mention:, steam_uid:)
        end
      end
    end
  end
end
