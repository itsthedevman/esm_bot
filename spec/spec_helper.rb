# frozen_string_literal: true

require_relative "./spec_helper_pre_init"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Timeout for rspec/wait, default timeout for requests
  config.wait_timeout = 5 # seconds

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before :suite do
    FactoryBot.find_definitions
    DatabaseCleaner.clean_with :deletion
    DatabaseCleaner.strategy = :deletion
  end

  config.after :suite do
    `kill -9 #{EXTENSION_SERVER.pid}`
    EXTENSION_SERVER.close
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      ESM::Test.reset!
      ESM::Connection::Server.pause

      # Run the test!
      example.run

      # Ensure every message is either replied to or timed out
      if example.metadata[:requires_connection]
        wait_for {
          ESM::Connection::Server.instance.message_overseer.size
        }.to eq(0)
      end

      ESM::Connection::Server.pause

      server = ESM::Connection::Server.instance
      server&.disconnect_all!
      server&.message_overseer&.remove_all!

      ESM::Websocket.remove_all_connections!
    end
  end
end

# Wait until everything is ready
# HEY! LISTEN! The following lines must be the last code to execute in this file
ESM.run!
ESM::Test.wait_until { ESM.bot.ready? }
ESM::Test.wait_until { ESM::Connection::Server.instance&.tcp_server_alive? }
