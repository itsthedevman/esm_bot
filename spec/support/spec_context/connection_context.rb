# frozen_string_literal: true

RSpec.shared_context("connection") do
  let!(:community) { ESM::Test.community }
  let!(:user) { ESM::Test.user }
  let!(:server) { ESM::Test.server(for: community) }
  let!(:connection_server) { ESM.connection_server }
  let(:_spawned_players) { [] }

  def execute_sqf!(code)
    ESM::Test.execute_sqf!(server, code, steam_uid: user.steam_uid)
  end

  before do |example|
    ESM.redis.del("server_key_set")

    next unless example.metadata[:requires_connection]

    # Store the server key so the build tool can pick it up and write it
    ESM.redis.set("server_key", server.token.to_json)
    debug!(server_key: server.token)

    # Removing all territories also checks that we're connected to MySQL
    ESM::ExileTerritory.delete_all

    # Callbacks
    ESM::Test.callbacks.run_callback(:before_connection, on_instance: self)

    connection_server.resume

    wait_for { ESM.redis.exists?("server_key_set") }.to be(true)
    wait_for { ESM.connection_server.allow_connections? }.to be(true)

    wait_for { server.reload.connected? }.to be(true),
      "esm_arma never connected. From the esm_arma repo, please run `bin/bot_testing`"

    # Add the ability to spawn players on the server
    allow_any_instance_of(ESM::User).to receive(:connect) do |user, **attrs|
      spawn_test_user(user, on: server, **attrs)
      _spawned_players << user
    end
  rescue ActiveRecord::ConnectionNotEstablished
    raise "Unable to connect to the Exile MySQL server. Please ensure it is running before trying again"
  end

  after do |example|
    connection_server.pause

    next unless example.metadata[:requires_connection]
    next if _spawned_players.size == 0

    users = _spawned_players.map_join("\n") do |user|
      next if user.steam_uid.blank?

      "ESM_TestUser_#{user.steam_uid} call _deleteFunction;" if user.connected
    end

    if users.present?
      sqf =
        <<~SQF
          private _deleteFunction = {
            if (isNil "_this") exitWith {};

            deleteVehicle _this;
          };
          #{users}
        SQF

      execute_sqf!(sqf)
    end
  end
end
