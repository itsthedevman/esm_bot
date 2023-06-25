# frozen_string_literal: true

module ESM
  class User
    class Ephemeral
      attr_reader :steam_uid, :discord_user

      def initialize(steam_uid)
        @steam_uid = steam_uid
        @discord_user = DiscordUser.new(steam_uid)
      end

      def registered?
        false
      end

      def id
        steam_uid
      end

      def steam_data
        @steam_data ||= ESM::SteamAccount.new(steam_uid)
      end

      class DiscordUser
        def initialize(esm_user)
          @esm_user = esm_user
        end

        delegate :steam_uid, to: :@esm_user

        alias_method :id, :steam_uid
        alias_method :mention, :steam_uid
        alias_method :distinct, :steam_uid
        alias_method :username, :steam_uid
      end
    end
  end
end
