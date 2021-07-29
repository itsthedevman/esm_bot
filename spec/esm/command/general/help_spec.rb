# frozen_string_literal: true

describe ESM::Command::General::Help, category: "command" do
  let!(:command) { ESM::Command::General::Help.new }

  it "should be valid" do
    expect(command).not_to be_nil
  end

  it "should have 1 argument" do
    expect(command.arguments.size).to eq(1)
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

    it "should execute with default getting started" do
      command_statement = command.statement
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed.title).to match(/my name is exile server manager/i)
      expect(embed.description).to eq(I18n.t("commands.help.getting_started.description"))
      expect(embed.fields.size).to eq(1)
      expect(embed.fields.first.name).to eq(I18n.t("commands.help.categories.name"))
      expect(embed.fields.first.value).to eq(I18n.t("commands.help.categories.value", prefix: ESM.config.prefix))
    end

    it "should return a valid embed (commands)" do
      command_statement = command.statement(category: "commands")
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be_nil
    end

    it "should return a valid embed (command)" do
      command_statement = command.statement(category: "help")
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be_nil
    end

    it "should not show admin commands if in player mode (commands)" do
      community.update(player_mode_enabled: true)

      command_statement = command.statement(category: "commands")
      event = CommandEvent.create(command_statement, user: user)
      expect {command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be_nil

      embed.fields.each do |field|
        expect(field.value).not_to match(/admin|development/i)
      end
    end

    it "should not show development commands" do
      command_statement = command.statement(category: "commands")
      event = CommandEvent.create(command_statement, user: user)
      expect { command.execute(event) }.not_to raise_error

      embed = ESM::Test.messages.first.second
      expect(embed).not_to be_nil

      embed.fields.each do |field|
        expect(field.value).not_to match(/development/i)
      end
    end
  end
end
