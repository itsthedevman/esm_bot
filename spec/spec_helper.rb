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
ActiveRecord::Base.logger.level = Logger::INFO if ActiveRecord::Base.logger.present?

`kill -9 $(pgrep -f esm_bot)`
`kill -9 $(pgrep -f esm_server)`

# Start the tcp_server
system("cargo build", "--release")
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

RSpec.shared_examples("connection") do
  let(:community) { ESM::Test.community }
  let(:server) { ESM::Test.server }
  let(:user) { ESM::Test.user }
  let(:connection) { server.connection }

  #
  # Sends the provided SQF code to the linked connection.
  #
  # @param code [String] Valid and error free SQF code as a string
  #
  # @return [Any] The result of the SQF code.
  #
  # @note: The result is ran through a JSON parser during the communication process. The type may not be what you expect, but it will be consistent
  #
  def execute_sqf!(code)
    message = ESM::Connection::Message.new(
      type: "arma",
      data_type: "sqf",
      data: {
        execute_on: "server",
        code: ESM::Arma::Sqf.minify(code)
      }
    )

    message.locals = {
      command: {
        current_user: {
          steam_uid: user.steam_uid || "",
          id: "",
          username: "",
          mention: ""
        }
      }.to_ostruct
    }

    message.apply_command_metadata

    connection.send_message(message, wait: true)
  end

  before(:each) do
    wait_for { server.connected? }.to be(true)

    ESM::Test.outbound_server_messages.clear

    # Creates a user on the server with the same steam_uid
    allow(user).to receive(:connect) { |**attrs| spawn_test_user(user, on: connection, **attrs) } if respond_to?(:user)
    allow(second_user).to receive(:connect) { |**attrs| spawn_test_user(second_user, on: connection, **attrs) } if respond_to?(:second_user)

    allow(user).to receive("connected?") { user.connected ||= false } if respond_to?(:user)
    allow(second_user).to receive("connected?") { second_user.connected ||= false } if respond_to?(:second_user)
  end

  after(:each) do
    users = ""
    users += "ESM_TestUser_#{user.steam_uid} call _deleteFunction;" if respond_to?(:user) && user.connected?
    users += "ESM_TestUser_#{second_user.steam_uid} call _deleteFunction;" if respond_to?(:second_user) && second_user.connected?
    next if users.blank?

    execute_sqf!(
      <<~SQF
        private _deleteFunction = {
          if (isNil "_this") exitWith {};

          deleteVehicle _this;
        };
        #{users}
      SQF
    )
  end
end

RSpec.shared_examples("command") do |described_class|
  let!(:command) { described_class.new }
  let(:community) { ESM::Test.community }
  let(:server) { ESM::Test.server }
  let(:user) { ESM::Test.user }

  def execute!(fail_on_raise: true, channel_type: :text, **command_args)
    command_statement = command.statement(command_args)
    event = CommandEvent.create(command_statement, user: user, channel_type: channel_type)

    if fail_on_raise
      expect { command.execute(event) }.not_to raise_error
    else
      command.execute(event)
    end
  end

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
    command.arguments.each do |argument|
      name = argument.name
      description = argument.opts[:description]

      expect(description).not_to be_nil, "Argument \"#{name}\" has a nil description"
      expect(description.match?(/^translation missing/i)).to be(false), "Argument \"#{name}\" does not have a valid entry. Ensure `commands.#{command.name}.arguments.#{name}` exists in `config/locales/commands/#{name}/en.yml`"
      expect(description.match?(/todo/i)).to be(false), "Argument \"#{name}\" has a TODO description"
    end
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
  community.command_configurations.where(command_name: command).update_all(whitelist_enabled: false)
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

def spawn_test_user(user, **attrs)
  attributes = {
    damage: 0,
    hunger: 100,
    thirst: 100,
    alcohol: 0,
    oxygen_remaining: 1,
    bleeding_remaining: 0,
    hitpoints: [["face_hub", 0], ["neck", 0], ["head", 0], ["pelvis", 0], ["spine1", 0], ["spine2", 0], ["spine3", 0], ["body", 0], ["arms", 0], ["hands", 0], ["legs", 0], ["body", 0]],
    direction: 0,
    position_x: 0,
    position_y: 0,
    position_z: 0,
    assigned_items: [],
    backpack: "",
    backpack_items: [],
    backpack_magazines: [],
    backpack_weapons: [],
    current_weapon: "",
    goggles: "",
    handgun_items: ["", "", "", ""],
    handgun_weapon: "",
    headgear: "",
    binocular: "",
    loaded_magazines: [],
    primary_weapon: "",
    primary_weapon_items: ["", "", "", ""],
    secondary_weapon: "",
    secondary_weapon_items: [],
    uniform: "",
    uniform_items: [],
    uniform_magazines: [],
    uniform_weapons: [],
    vest: "",
    vest_items: [],
    vest_magazines: [],
    vest_weapons: [],
    account_money: 0,
    account_score: 0,
    account_kills: 0,
    account_deaths: 0,
    clan_id: "",
    clan_name: "",
    temperature: 37,
    wetness: 0,
    account_locker: 0
  }

  attributes.each { |key, value| attributes[key] = attrs[key] || value }

  # Offset the unused values
  data = ["", "", ""] + attributes.values

  sqf = <<~SQF
    private _data = #{data};
    private _pos2D = (call ExileClient_util_world_getAllAirportPositions) select 0;

    _data set [11, _pos2D select 0];
    _data set [12, _pos2D select 1];

    [_data, objNull, "#{user.steam_uid}", 0] call ExileServer_object_player_database_load;
    _createdPlayer = ([_pos2D select 0, _pos2D select 1, 0] nearEntities ["Exile_Unit_Player", 100]) select 0;
    if (isNil "_createdPlayer") exitWith {};

    ESM_TestUser_#{user.steam_uid} = _createdPlayer;
    _createdPlayer allowDamage false;
    _createdPlayer setDamage 0;

    netId _createdPlayer
  SQF

  response = execute_sqf!(sqf)
  expect(response).not_to be_nil

  # Remove the request and response
  ESM::Test.outbound_server_messages.pop
  ESM::Test.inbound_server_messages.pop

  net_id = response.data.result
  expect(net_id).not_to be_nil

  user.connected = true
  net_id
end

# Wait until everything is ready
# HEY! LISTEN! The following lines must be the last code to execute in this file
ESM.run!
ESM::Test.wait_until { ESM.bot.ready? }
ESM::Test.wait_until { ESM::Connection::Server.instance.tcp_server_alive? }
