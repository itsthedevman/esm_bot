# frozen_string_literal: true

class CommandEvent
  # Can't use initializer because I want to return a different object. This is essentially a wrapper
  def self.create(content, user:, channel_type: :text)
    # This command is expensive in the terms of requests to Discord.
    # The bot can only send 50 requests per second
    sleep(0.05)

    data = {
      "id" => nil,
      "content" => content,
      "channel_id" => ((channel_type == :text) ? ESM::Test.data[user.guild_type][:channels].sample : user.discord_user.pm.id),
      "guild_id" => ESM::Test.data[user.guild_type][:server_id],
      "pinned" => false,
      "author" => {
        "id" => user.discord_id,
        "discriminator" => user.discord_discriminator,
        "username" => user.discord_username
      }
    }

    message = Discordrb::Message.new(data, ESM.bot)
    Discordrb::Commands::CommandEvent.new(message, ESM.bot)
  end
end
