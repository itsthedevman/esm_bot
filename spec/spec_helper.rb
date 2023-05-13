# frozen_string_literal: true

# Set to zero for indefinite
SPEC_TIMEOUT_SECONDS = 3
LOG_LEVEL = :warn

RSpec.configure do |config|
  require_relative "./spec_helper_pre_init"

  config.include FactoryBot::Syntax::Methods

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Timeout for rspec/wait, default timeout for requests
  config.wait_timeout = SPEC_TIMEOUT_SECONDS.zero? ? 999_999_999 : SPEC_TIMEOUT_SECONDS

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before :suite do
    FactoryBot.find_definitions
    DatabaseCleaner.clean_with :deletion
    DatabaseCleaner.strategy = :deletion

    # Build script generates territories
    ESM::ExileTerritory.delete_all
  end

  config.after :suite do
    `kill -9 $(pgrep -f esm_extension_server) > /dev/null 2>&1 && kill -9 $(pgrep -f esm_bot) > /dev/null 2>&1`
    EXTENSION_SERVER.close
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      ESM::Test.reset!
      ESM::Connection::Server.pause

      debug!(
        example_group: example.example_group&.description,
        example: example.description
      )

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

  config.before(:context, :territory_admin_bypass) do
    before_connection do
      community.update!(territory_admin_ids: [community.everyone_role_id])
    end
  end

  config.after(:context, :territory_admin_bypass) do
    ESM::Test.callbacks.remove_all_callbacks!
  end

  config.before(:context, :error_testing) do
    disable_log_printing
  end

  config.after(:context, :error_testing) do
    enable_log_printing
  end
end

# Wait until everything is ready
# HEY! LISTEN! The following lines must be the last code to execute in this file
ESM.console!
ESM.run!
ESM::Test.wait_until { ESM.bot.ready? }
ESM::Test.wait_until { ESM::Connection::Server.instance&.tcp_server_alive? }
