# frozen_string_literal: true

module Discordrb
  class User
    attr_writer :esm_user

    delegate :steam_uid, :id_defaults, :id_aliases, to: :esm_user

    def esm_user
      @esm_user ||= lambda do
        user = ESM::User.where(discord_id: id.to_s).first_or_initialize
        user.update(discord_username: username, discord_discriminator: discriminator)
        user
      end.call
    end

    def to_h
      {
        id: id.to_s,
        username: username,
        discriminator: discriminator,
        avatar_url: avatar_url
      }
    end
  end
end
