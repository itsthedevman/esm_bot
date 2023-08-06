# frozen_string_literal: true

describe ESM::Websocket do
  # This test requires esm_community/esm_server
  let!(:esm_community) { create(:esm_community) }
  let!(:esm_malden) { create(:esm_malden, community_id: esm_community.id) }
  let!(:esm_malden_wsc) { WebsocketClient.new(esm_malden) }

  before do
    wait_for { esm_malden_wsc.connected? }.to be(true)
  end

  after do
    esm_malden_wsc.disconnect!
  end

  it "should raise invalid key" do
    bad_ws = WebsocketClient.new(OpenStruct.new(server_key: "Nope!", server_id: "Nope!"))
    expect(bad_ws).not_to be_nil
    wait_for { bad_ws.connected? }.to be(false)
  end

  describe "Connections" do
    let!(:second_community) { create(:secondary_community) }
    let!(:second_server) { create(:server, community_id: second_community.id) }
    let!(:second_connection) { WebsocketClient.new(second_server) }

    before do
      wait_for { second_connection.connected? }.to be(true)
    end

    after do
      second_connection.disconnect!
    end

    it "should add" do
      expect(ESM::Websocket.connections[second_server.server_id]).not_to be_nil
    end

    it "should remove" do
      other_connection = ESM::Websocket.connections[second_server.server_id]

      expect(other_connection).not_to be_nil
      expect { ESM::Websocket.remove_connection(other_connection) }.not_to raise_error
      expect(ESM::Websocket.connections[second_server.server_id]).to be_nil
    end
  end

  describe "#deliver!" do
    it "should deliver" do
      connection = ESM::Websocket.connections[esm_malden.server_id]

      user = ESM::Test.user.discord_user
      command = ESM::Command::Test::BaseV1.new

      request = ESM::Websocket::Request.new(
        command: command,
        user: user,
        channel: nil,
        parameters: [],
        timeout: 15
      )

      ESM::Websocket.deliver!(esm_malden.server_id, request)

      expect(connection.requests.size).to eq(1)
    end
  end

  describe "#correct" do
    it "should provide no corrections" do
      server = ESM::Server.all.sample(1).first
      correction = ESM::Websocket.correct(server.server_id)

      expect(correction).to be_blank
    end

    it "should provide a correction" do
      server = ESM::Server.all.sample(1).first
      correction = ESM::Websocket.correct(server.server_id[0..-3])

      expect(correction).not_to be_blank
      expect(correction.first).to eq(server.server_id)
    end
  end

  describe "#on_message" do
    let!(:user) { create(:user) }
    let!(:ws_connection) { ESM::Websocket.connections[esm_malden.server_id] }
    let!(:channel) { ESM.bot.channel(ESM::Community::ESM::SPAM_CHANNEL) }
    let!(:discord_user) { user.discord_user }

    let!(:command) do
      command = ESM::Command::Test::BaseV1.new

      command_statement = command.statement(
        community_id: esm_community.community_id,
        server_id: esm_malden.server_id,
        target: user.discord_id,
        _integer: "1",
        _preserve: "PRESERVE",
        _display_as: "display_name",
        _default: "default"
      )

      event = CommandEvent.create(command_statement, user: user)

      # Execute the command to set up all of the required variables
      expect { command.execute(event) }.not_to raise_error
      command
    end

    let(:request) do
      request = ESM::Websocket::Request.new(
        command: command,
        user: user,
        channel: channel,
        parameters: [],
        timeout: 15
      )

      ws_connection.requests << request
      request
    end

    # Ignored commands do not remove the request.
    it "should handle ignored requests" do
      message = {
        commandID: request.id,
        ignore: true
      }.to_json

      expect(ws_connection.requests.size).to eq(1)
      ws_connection.send(:on_message, OpenStruct.new(data: message))
      expect(ws_connection.requests.size).to eq(1)
    end

    it "should send an error message (error)" do
      message = {
        commandID: request.id,
        error: Faker::Lorem.sentence
      }.to_json

      ws_connection.send(:on_message, OpenStruct.new(data: message))

      message = message.to_ostruct
      wait_for { ESM::Test.messages.size }.to eq(1)
      error_message = ESM::Test.messages.first.second

      expect(error_message).not_to be_nil
      expect(error_message.description).to eq("#{discord_user.mention}, #{message.error}")
      expect(error_message.color).to eq("#C62551")
    end

    it "should send an error message (parameters)" do
      message = {
        commandID: request.id,
        parameters: [{
          error: Faker::Lorem.sentence
        }]
      }.to_json

      ws_connection.send(:on_message, OpenStruct.new(data: message))

      message = message.to_ostruct
      wait_for { ESM::Test.messages.size }.to eq(1)
      error_message = ESM::Test.messages.first.second

      expect(error_message).not_to be_nil
      expect(error_message.description).to eq("#{discord_user.mention}, #{message.parameters.first.error}")
      expect(error_message.color).to eq("#C62551")
    end
  end

  describe "#on_open" do
    it "should send connect message"
  end

  describe "#on_close" do
    it "should send disconnect message"
  end
end
