# frozen_string_literal: true

# Set to false for indefinite
SPEC_TIMEOUT_SECONDS = 5
LOG_LEVEL = :debug

require_relative "config"

RSpec.configure do |config|
  config.before :suite do
    FactoryBot.definition_file_paths = [ESM.root.join("spec", "support", "factories")]
    FactoryBot.find_definitions

    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner[:active_record, db: ESM::ExileAccount].strategy = :truncation
  end

  config.around do |example|
    trace!(
      example_group: example.example_group&.description,
      example: example.description
    )

    ESM::Test.reset!
    ESM.connection_server.pause

    # Run the test!
    DatabaseCleaner.cleaning { example.run }
  end
end

# Wait until everything is ready
# HEY! LISTEN! The following lines must be the last code to execute in this file
ESM.run!(async: true)
ESM::Test.wait_until { ESM::Database.connected? }
ESM::Test.wait_until { ESM.bot.ready? }
