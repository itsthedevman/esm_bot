# frozen_string_literal: true

describe ESM::Command::Player::Preferences, category: "command" do
  let!(:command) { ESM::Command::Player::Preferences.new }

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
    let!(:types) { ESM::Command::Player::Preferences::TYPES.dup[1..] }
    let(:type) { types.sample }
    let(:preference) { ESM::UserNotificationPreference.where(server_id: server.id, user_id: user.id).first }

    it "should set permissions (Allow/All)" do
      command_statement = command.statement(server_id: server.server_id, state: "allow")
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { command.execute(event) }.not_to raise_error

      message = ESM::Test.messages.first.second
      expect(message).not_to be_nil
      expect(message.description).to match(/your preferences for `.+` have been updated/i)

      types.each do |type|
        expect(preference.send(type.underscore)).to be(true)
      end
    end

    it "should set permissions (Allow/Single)" do
      command_statement = command.statement(server_id: server.server_id, type: type, state: "allow")
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { command.execute(event) }.not_to raise_error

      message = ESM::Test.messages.first.second
      expect(message).not_to be_nil
      expect(message.description).to match(/your preferences for `.+` have been updated/i)

      expect(preference.send(type.underscore)).to be(true)
    end

    it "should set permissions (Deny/All)" do
      command_statement = command.statement(server_id: server.server_id, state: "deny")
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { command.execute(event) }.not_to raise_error

      message = ESM::Test.messages.first.second
      expect(message).not_to be_nil
      expect(message.description).to match(/your preferences for `.+` have been updated/i)

      types.each do |type|
        expect(preference.send(type.underscore)).to be(false)
      end
    end

    it "should set permissions (Deny/Single)" do
      command_statement = command.statement(server_id: server.server_id, type: type, state: "deny")
      event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

      expect { command.execute(event) }.not_to raise_error

      message = ESM::Test.messages.first.second
      expect(message).not_to be_nil
      expect(message.description).to match(/your preferences for `.+` have been updated/i)

      expect(preference.send(type.underscore)).to be(false)
    end
  end
end
