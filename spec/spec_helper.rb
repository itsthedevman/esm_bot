# frozen_string_literal: true

# Set to zero for indefinite
SPEC_TIMEOUT_SECONDS = 3
LOG_LEVEL = :error

RSpec.configure do |config|
  require_relative "spec_helper_pre_init"

  config.include FactoryBot::Syntax::Methods

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Timeout for rspec/wait, default timeout for requests
  config.wait_timeout = SPEC_TIMEOUT_SECONDS.zero? ? 999_999_999 : SPEC_TIMEOUT_SECONDS

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before :suite do
    FactoryBot.definition_file_paths = [ESM.root.join("spec", "support", "factories")]
    FactoryBot.find_definitions
    DatabaseCleaner.strategy = :deletion
  end

  config.around do |example|
    trace!(
      example_group: example.example_group&.description,
      example: example.description
    )

    ESM::Test.reset!

    # Run the test!
    DatabaseCleaner.cleaning { example.run }

    ESM::Websocket.remove_all_connections!
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
ESM::Test.wait_until { ESM::Database.connected? }
ESM::Test.wait_until { ESM.bot.ready? }
