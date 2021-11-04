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

  config.before :example do
    ESM::Test.reset!
  end

  config.after :example do
    ESM::Test.skip_cooldown = false
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      if example.metadata[:requires_connection]
        ESM::Connection::Server.run! if ESM::Connection::Server.instance.nil?
        ESM::Test.wait_until { ESM::Connection::Server.instance.tcp_server_alive? }
      else
        ESM::Connection::Server.stop!
      end

      example.run
    end

    ESM::Websocket.remove_all_connections!
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

# Wait until the bot has fully connected
ESM::Test.wait_until { ESM.bot.ready? }
