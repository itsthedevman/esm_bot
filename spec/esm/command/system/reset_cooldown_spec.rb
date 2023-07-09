# frozen_string_literal: true

describe ESM::Command::Community::ResetCooldown, category: "command" do
  let!(:command) { ESM::Command::Community::ResetCooldown.new }

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
    let(:second_community) { ESM::Test.second_community }
    let(:second_server) { ESM::Test.second_server }
    let(:second_user) { ESM::Test.user }
    let!(:target_regex) { ESM::Regex::TARGET.source }

    let!(:cooldown_one) do
      create(
        :cooldown,
        user_id: second_user.id,
        community_id: community.id,
        server_id: server.id,
        command_name: "me",
        expires_at: Time.now + 5.minutes,
        cooldown_type: "minutes",
        cooldown_quantity: 5
      )
    end

    let!(:cooldown_two) do
      create(
        :cooldown,
        user_id: second_user.id,
        community_id: community.id,
        server_id: second_server.id,
        command_name: "me",
        expires_at: Time.now + 5.minutes,
        cooldown_type: "minutes",
        cooldown_quantity: 5
      )
    end

    before :each do
      # Grant everyone access to use this command
      grant_command_access!(community, "reset_cooldown")

      # Force the configuration to be correct
      community.command_configurations
        .where(command_name: "me")
        .update_all(cooldown_type: "minutes", cooldown_quantity: 5)

      expect(cooldown_one.active?).to be(true)
      expect(cooldown_two.active?).to be(true)
    end

    it "!reset_cooldown <target>" do
      command_statement = command.statement(target: second_user.mention)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error
      wait_for { ESM::Test.messages.size }.to eq(2)

      # Check success message
      response = ESM::Test.messages.first.second
      expect(response).not_to be(nil)
      expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for your community/i)

      # Check confirmation embed
      confirmation_embed = ESM::Test.messages.first.second

      expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for all commands\. this change will be applied to every server your community has registered with me\./i)
      expect(confirmation_embed.fields.size).to eq(1)

      # Check cooldowns
      expect(cooldown_one.reload.active?).to be(false)
      expect(cooldown_two.reload.active?).to be(false)
    end

    it "!reset_cooldown <target> <command_name>" do
      command_statement = command.statement(target: second_user.mention, command_name: "me")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error
      wait_for { ESM::Test.messages.size }.to eq(2)

      # Check success message
      response = ESM::Test.messages.first.second
      expect(response).not_to be(nil)
      expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for `me` on every server your community has registered with me\./i)

      # Check confirmation embed
      confirmation_embed = ESM::Test.messages.first.second

      expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for `me`\. this change will be applied to every server your community has registered with me\./i)
      expect(confirmation_embed.fields.size).to eq(1)

      # Check cooldowns
      expect(cooldown_one.reload.active?).to be(false)
      expect(cooldown_two.reload.active?).to be(false)
    end

    it "!reset_cooldown <target> <command_name> <server_id>" do
      command_statement = command.statement(target: second_user.mention, command_name: "me", server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error
      wait_for { ESM::Test.messages.size }.to eq(2)

      # Check success message
      response = ESM::Test.messages.first.second
      expect(response).not_to be(nil)
      expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for `me` . this change will only be applied to `#{server.server_id}`/i)

      # Check confirmation embed
      confirmation_embed = ESM::Test.messages.first.second

      expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for `me`. this change will only be applied to `#{server.server_id}`/i)
      expect(confirmation_embed.fields.size).to eq(1)

      # Check cooldowns
      expect(cooldown_one.reload.active?).to be(false)
      expect(cooldown_two.reload.active?).to be(true)
    end

    it "!reset_cooldown <target> <server_id>" do
      command_statement = command.statement(target: second_user.mention, server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error
      wait_for { ESM::Test.messages.size }.to eq(2)

      # Check success message
      response = ESM::Test.messages.first.second
      expect(response).not_to be(nil)
      expect(response.description).to match(/hey #{target_regex}, i have reset #{target_regex}'s cooldowns for all commands on `#{server.server_id}`/i)

      # Check confirmation embed
      confirmation_embed = ESM::Test.messages.first.second

      expect(confirmation_embed.description).to match(/just to confirm, i will be resetting #{target_regex}'s cooldowns for all commands\. this change will only be applied to `#{server.server_id}`/i)
      expect(confirmation_embed.fields.size).to eq(1)

      # Check cooldowns
      expect(cooldown_one.reload.active?).to be(false)
      expect(cooldown_two.reload.active?).to be(true)
    end

    it "!reset_cooldown <command_name>" do
      command_statement = command.statement(command_name: "me")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error
      wait_for { ESM::Test.messages.size }.to eq(2)

      # Check success message
      response = ESM::Test.messages.first.second
      expect(response).not_to be(nil)
      expect(response.description).to match(/hey #{target_regex}, i have reset everyone's cooldowns for `me` on every server your community has registered with me.`/i)

      # Check confirmation embed
      confirmation_embed = ESM::Test.messages.first.second

      expect(confirmation_embed.description).to match(/just to confirm, i will be resetting everyone's cooldowns for `me`\. this change will be applied to every server your community has registered with me\./i)
      expect(confirmation_embed.fields.size).to eq(1)

      # Check cooldowns
      expect(cooldown_one.reload.active?).to be(false)
      expect(cooldown_two.reload.active?).to be(false)
    end

    it "!reset_cooldown <command_name> <server_id>" do
      command_statement = command.statement(command_name: "me", server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "yes"
      expect { command.execute(event) }.not_to raise_error
      wait_for { ESM::Test.messages.size }.to eq(2)

      # Check success message
      response = ESM::Test.messages.first.second
      expect(response).not_to be(nil)
      expect(response.description).to match(/hey #{target_regex}, i have reset everyone's cooldowns for `me` on `#{server.server_id}`/i)

      # Check confirmation embed
      confirmation_embed = ESM::Test.messages.first.second

      expect(confirmation_embed.description).to match(/just to confirm, i will be resetting everyone's cooldowns for `me`\. this change will only be applied to `#{server.server_id}`/i)
      expect(confirmation_embed.fields.size).to eq(1)

      # Check cooldowns
      expect(cooldown_one.reload.active?).to be(false)
      expect(cooldown_two.reload.active?).to be(true)
    end

    it "should raise error (Invalid Command)" do
      command_statement = command.statement(target: second_user.mention, command_name: "NOUP")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure)
    end

    it "should decline" do
      command_statement = command.statement(target: second_user.mention, command_name: "me", server_id: server.server_id)
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      ESM::Test.response = "no"
      expect { command.execute(event) }.not_to raise_error
      wait_for { ESM::Test.messages.size }.to eq(2)

      # Check success message
      response = ESM::Test.messages.second.second
      expect(response).not_to be(nil)
      expect(response).to match(/i've cancelled your request/i)
    end

    it "should not allow an un-registered steam uid" do
      steam_uid = second_user.steam_uid
      second_user.update(steam_uid: "")

      command_statement = command.statement(target: steam_uid, command_name: "me")
      event = CommandEvent.create(command_statement, user: user, channel_type: :text)

      expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure, /not registered/i)
    end
  end
end
