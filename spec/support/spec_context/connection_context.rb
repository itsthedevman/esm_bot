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

    connection_server.start
  end

  after do |example|
    connection_server.stop

    next unless example.metadata[:requires_connection]
  end
end
