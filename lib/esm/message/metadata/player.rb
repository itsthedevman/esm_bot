# frozen_string_literal: true

module ESM
  class Message
    class Metadata
      class Player < ImmutableStruct.define(:discord_id, :discord_name, :discord_mention, :steam_uid)
        def self.from(user)
          case user
          when ESM::User
            new(
              steam_uid: user.steam_uid,
              discord_id: user.discord_id,
              discord_name: user.discord_username,
              discord_mention: user.mention
            )
          when ESM::User::Ephemeral
            new(steam_uid: user.steam_uid)
          else
            new(**Hash[members.zip].merge(user)) # rubocop:disable Style/HashConversion
          end
        end

        def to_h
          super.delete_if { |_k, v| v.nil? }
        end
      end
    end
  end
end
