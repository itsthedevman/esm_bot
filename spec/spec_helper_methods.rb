# frozen_string_literal: true

def create_request(**params)
  user = ESM::Test.user.discord_user
  command = ESM::Command::Test::BaseV1.new

  ESM::Websocket::Request.new(
    command: command,
    user: user,
    channel: ESM.bot.channel(ESM::Community::ESM::SPAM_CHANNEL),
    parameters: params
  )
end

# Disables the allowlist on admin commands so the tests can use them
def grant_command_access!(community, command)
  community.command_configurations.where(command_name: command).update_all(allowlist_enabled: false)
end

#
# Mimics sending a discord message for a test.
#
# @param message [String, ESM::Embed] The message to "send"
#
def send_discord_message(message)
  ESM::Test.response = message
end

#
# Waits for a message to be sent from the bot to the server
#
# @return [ESM::Message]
#
def wait_for_outbound_message
  message = nil
  wait_for { message = ESM::Test.outbound_server_messages.shift }.to be_truthy
  message.content
end

#
# Waits for a message to be sent from the client to the bot
#
# @return [ESM::Message]
#
def wait_for_inbound_message
  message = nil
  wait_for { message = ESM::Test.inbound_server_messages.shift }.to be_truthy
  message.content
end

def enable_log_printing
  ENV["PRINT_LOG"] = "true"
end

def disable_log_printing
  ENV["PRINT_LOG"] = "false"
end

def before_connection(&block)
  ESM::Test.callbacks.add_callback(:before_connection, &block)
end

def messages
  ESM::Test.messages.contents
end

def earliest_message
  ESM::Test.messages.earliest
end

def latest_message
  ESM::Test.messages.latest
end
