# frozen_string_literal: true

RSpec.shared_context("connection") do
  let!(:community) { ESM::Test.community }
  let!(:user) { ESM::Test.user }
  let(:server) { ESM::Test.server }
  let(:connection_server) { ESM.connection_server }

  def execute_sqf!(code)
    ESM::Test.execute_sqf!(server, code, steam_uid: user.steam_uid)
  end

  before do |example|
    connection_server.stop
    next unless example.metadata[:requires_connection]

    ESM::ExileTerritory.delete_all
    ESM::Test.callbacks.run_callback(:before_connection, on_instance: self)

    connection_server.start

    wait_for { server.reload.connected? }.to be(true),
      "esm_arma never connected. From the esm_arma repo, please run `bin/bot_testing`"

    ESM::Test.outbound_server_messages.clear

    users = []
    users << user if respond_to?(:user)
    users << second_user if respond_to?(:second_user)
    next if users.blank?

    users.each do |user|
      # Creates a user on the server with the same steam_uid
      allow(user).to receive(:connect) { |**attrs| spawn_test_user(user, on: server, **attrs) }
    end
    info!("initialized")
  rescue ActiveRecord::ConnectionNotEstablished
    raise "Unable to connect to the Exile MySQL server. Please ensure it is running before trying again"
  end

  after do |example|
    connection_server.stop

    next unless example.metadata[:requires_connection]

    users = []
    users << user if respond_to?(:user)
    users << second_user if respond_to?(:second_user)

    users = users.format(join_with: "\n") do |user|
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
