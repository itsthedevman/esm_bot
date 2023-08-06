# frozen_string_literal: true

describe ESM::Command::Territory::Demote, category: "command" do
  let!(:command) { ESM::Command::Territory::Demote.new }
  let(:territory_id) { Faker::Alphanumeric.alphanumeric(number: 3..30) }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 3 argument" do
    expect(command.arguments.size).to eq(3)
  end

  it "should have a description" do
    expect(command.description).not_to be_blank
  end

  it "should have examples" do
    expect(command.example).not_to be_blank
  end

  describe "#execute" do
    let!(:community) { ESM::Test.community }
    let!(:server) { ESM::Test.server }
    let!(:user) { ESM::Test.user }

    # If you need a second set
    let(:second_user) { ESM::Test.user }

    # If you need to connect to a server
    let!(:wsc) { WebsocketClient.new(server) }
    let(:connection) { ESM::Websocket.connections[server.server_id] }
    let(:response) { command.response }

    before do
      wait_for { wsc.connected? }.to be(true)
    end

    after do
      wsc.disconnect!
    end

    it "!demote" do
      command_statement = command.statement(
        server_id: server.server_id,
        territory_id: territory_id,
        target: second_user.mention
      )
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      request = nil
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      wait_for { ESM::Test.messages.size }.to eq(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(
        /hey #{user.mention}, `#{second_user.steam_uid}` has been demoted to builder in territory `#{territory_id}` on `#{server.server_id}`/i
      )
    end

    it "!demote (Unregistered discord target)" do
      second_user.update(steam_uid: "")

      command_statement = command.statement(
        server_id: server.server_id,
        territory_id: territory_id,
        target: second_user.mention
      )
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure) do |error|
        embed = error.data
        expect(embed.description).to match(/has not registered with me yet/i)
      end
    end

    it "!demote (Unlinked steam uid)" do
      steam_uid = second_user.steam_uid
      second_user.update(steam_uid: "")

      command_statement = command.statement(
        server_id: server.server_id,
        territory_id: territory_id,
        target: steam_uid
      )
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      request = nil
      expect { request = command.execute(event) }.not_to raise_error
      expect(request).not_to be_nil
      wait_for { connection.requests }.to be_blank
      wait_for { ESM::Test.messages.size }.to eq(1)

      embed = ESM::Test.messages.first.second
      expect(embed.description).to match(
        /hey #{user.mention}, `#{steam_uid}` has been demoted to builder in territory `#{territory_id}` on `#{server.server_id}`/i
      )
    end
  end
end
