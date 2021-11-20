# frozen_string_literal: true

# Set our env to test
ENV["ESM_ENV"] = "test"
ENV["PRINT_LOG"] = "true"

require "bundler/setup"
require "awesome_print"
require "colorize"
require "database_cleaner"
require "pry"
require "esm"
require "factory_bot"
require "faker"
require "rspec/expectations"
require "rspec/wait"
require "neatjson"

require_relative "./support/esm/command/base"

# Load all of our support files
loader = Zeitwerk::Loader.new
loader.inflector.inflect("esm" => "ESM")
loader.push_dir("#{__dir__}/support")
loader.collapse("#{__dir__}/support/model")

# Load everything right meow
loader.setup
loader.eager_load

# Enable discordrb logging
Discordrb::LOGGER.debug = false

# Ignore debug messages when running tests
ActiveRecord::Base.logger.level = Logger::INFO

`kill -9 $(pgrep -f esm_bot)`
`kill -9 $(pgrep -f esm_server)`

# Start the bot
ESM.run!

# Start the tcp_server
TCP_SERVER = IO.popen("bin/tcp_server")

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Timeout for rspec/wait, default timeout for requests
  config.wait_timeout = 10 # seconds

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before :suite do
    FactoryBot.find_definitions
    DatabaseCleaner.clean_with :deletion
    DatabaseCleaner.strategy = :deletion
  end

  config.after :suite do
    `kill -9 #{TCP_SERVER.pid}`
    TCP_SERVER.close
  end

  config.around(:each) do |example|
    server = ESM::Connection::Server.instance
    server.disconnect_all!
    server.message_overseer&.remove_all!
    server.refresh_keys

    DatabaseCleaner.cleaning do
      if example.metadata[:requires_connection]
        ESM::Connection::Server.resume
      else
        ESM::Connection::Server.pause
      end

      ESM::Test.reset!

      # Run the test!
      example.run

      # Ensure every message is either replied to or timed out
      wait_for { ESM::Connection::Server.instance.message_overseer.size }.to eq(0) if example.metadata[:requires_connection]

      ESM::Websocket.remove_all_connections!
    end
  end
end

RSpec.shared_context("connection") do
  let(:connection) { server.connection }
  before(:each) do
    wait_for { server.connected? }.to be(true)
    
    ESM::Test.outbound_server_messages.clear
  end
end

RSpec.shared_examples("command") do |described_class|
  def execute!(channel_type: :text, **command_args)
    command_statement = command.statement(command_args)
    event = CommandEvent.create(command_statement, user: user, channel_type: channel_type)
    expect { command.execute(event) }.not_to raise_error
  end

  let!(:command) { described_class.new }
  let(:community) { ESM::Test.community }
  let(:server) { ESM::Test.server }
  let(:user) { ESM::Test.user }

  it "has a valid description text" do
    expect(command.description).not_to be_blank
    expect(command.description).not_to match(/todo/i)
  end

  it "has a valid example text" do
    expect(command.example).not_to be_blank
    expect(command.example).not_to match(/todo/i)
  end

  it "has the required defines" do
    defines = command.defines.to_h
    expect(defines).to have_key(:enabled)
    expect(defines).to have_key(:whitelist_enabled)
    expect(defines).to have_key(:whitelisted_role_ids)
    expect(defines).to have_key(:allowed_in_text_channels)
    expect(defines).to have_key(:cooldown_time)
  end

  it "has valid description text for every argument" do
    descriptions = command.arguments.map { |a| a.opts[:description] }
    expect(descriptions.any?(&:nil?)).to be(false)

    result = descriptions.any? { |description| description.match?(/^translation missing/i) || description.match?(/todo/i) }
    expect(result).to be(false)
  end
end

def create_request(**params)
  user = ESM.bot.user(TestUser::User1::ID)
  command = ESM::Command::Test::Base.new

  ESM::Websocket::Request.new(
    command: command,
    user: user,
    channel: ESM.bot.channel(ESM::Community::ESM::SPAM_CHANNEL),
    parameters: params
  )
end

# Disables the whitelist on admin commands so the tests can use them
def grant_command_access!(community, command)
  community.command_configurations.where(command_name: command).update(whitelist_enabled: false)
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
# @return [ESM::Connection::Message]
#
def wait_for_outbound_message
  message = nil
  wait_for { message = ESM::Test.outbound_server_messages.shift }.to be_truthy
  message.content
end

#
# Waits for a message to be sent from the client to the bot
#
# @return [ESM::Connection::Message]
#
def wait_for_inbound_message
  message = nil
  wait_for { message = ESM::Test.inbound_server_messages.shift }.to be_truthy
  message.content
end

# Wait until the bot has fully connected
ESM::Test.wait_until { ESM.bot.ready? }
ESM::Test.wait_until { ESM::Connection::Server.instance.tcp_server_alive? }
