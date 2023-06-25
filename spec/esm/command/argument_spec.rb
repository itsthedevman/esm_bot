# frozen_string_literal: true

describe ESM::Command::Argument do
  let!(:command) { ESM::Command::Test::PlayerCommand.new }

  describe "Valid Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, {regex: /foo/, description: "Test"}) }

    it "is a valid argument" do
      expect(argument).not_to be_nil
    end

    it "has regex" do
      expect(argument.regex).not_to be_nil
      expect(argument.regex).to eq("(?<foo>\\s+(?:foo))?")
    end
  end

  describe "Display Name Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, {regex: /foo/, display_name: "FOOBAR", description: "Test"}) }

    it "has a different display name" do
      expect(argument.display_name).not_to be_nil
      expect(argument.display_name).to eq("FOOBAR")
      expect(argument.name).not_to eq(argument.display_name)
    end
  end

  describe "Type Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, {regex: /12345/, type: :integer, description: "Test"}) }

    it "is a integer" do
      expect(argument.type).to eq(:integer)
    end
  end

  describe "Case Preserved Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, {regex: /Foo/, preserve: true, description: "Test"}) }

    it "preserves its case" do
      expect(argument.preserve_case?).to be(true)
    end
  end

  describe "Default Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, {regex: /hello/, default: "Hello World", description: "Test"}) }

    it "has a default value" do
      expect(argument.default_value?).to be(true)
      expect(argument.default_value).to eq("Hello World")
    end
  end

  describe "Description Argument" do
    let(:argument) { ESM::Command::Argument.new(:foo, {regex: /hello/, description: "test"}) }

    it "has a description" do
      expect(argument.description).to eq("This is a test")
    end
  end

  describe "Argument with default values" do
    let(:argument) { ESM::Command::Argument.new(:foo, {regex: /.+/, description: "test"}) }

    it "does not preserve case" do
      expect(argument.preserve_case?).to be(false)
    end

    it "is a string" do
      expect(argument.type).to eq(:string)
    end

    it "has a display name" do
      expect(argument.display_name).to eq("foo")
    end

    it "has a nil default" do
      expect(argument.default).to be_nil
    end

    it "does not have a default" do
      expect(argument.default_value?).to be(false)
    end

    it "has a description" do
      expect(argument.description).to eq("This is a test")
    end
  end

  describe "#to_s" do
    it "is a standard argument" do
      argument = ESM::Command::Argument.new(:foo, {regex: /.+/, description: "test"})
      expect(argument.to_s).to eq("<foo>")
    end

    it "is an optional argument" do
      argument = ESM::Command::Argument.new(:foo, {regex: /.+/, default: "foobar", description: "test"})
      expect(argument.to_s).to eq("<?foo>")
    end

    it "uses the display_name" do
      argument = ESM::Command::Argument.new(:foo, {regex: /.+/, display_name: "bar", description: "test"})
      expect(argument.to_s).to eq("<bar>")
    end
  end

  describe "Argument with template name" do
    it "has defaults" do
      argument = ESM::Command::Argument.new(:server_id, {})

      expect(argument.regex).to eq(
        "(?<server_id>\\s+(?:#{ESM::Regex::SERVER_ID_OPTIONAL_COMMUNITY.source}))?"
      )

      expect(argument.description).not_to be_blank
    end
  end

  describe "Argument with template keyword" do
    it "gets defaults" do
      argument = ESM::Command::Argument.new(:some_other_argument, {template: :server_id})
      expect(argument.name).to eq(:some_other_argument)
      expect(argument.regex).to eq(
        "(?<some_other_argument>\\s+(?:#{ESM::Regex::SERVER_ID_OPTIONAL_COMMUNITY.source}))?"
      )
      expect(argument.description).to match(/The ID for the server that you want to run this command on/i)
    end
  end

  describe "#parse" do
    let!(:user) { ESM::Test.user }
    let!(:server) { ESM::Test.server }
    let(:second_server) { ESM::Test.second_server }
    let!(:command) { ESM::Command::Test::CommunityAndServerCommand.new }
    let!(:command_statement) { command.statement }
    let(:text_event) { CommandEvent.create(command_statement, user: user, channel_type: :text) }
    let(:pm_event) { CommandEvent.create(command_statement, user: user, channel_type: :pm) }
    let(:community) { command.current_community } # Only call in tests

    before :each do
      command.event = text_event
    end

    describe "community_id modifier" do
      let!(:argument) { described_class.new(:community_id, {}) }

      it "returns the user's alias" do
        command.current_user.id_aliases.create!(community: community, value: "c")

        argument.store("c", command)
        expect(argument.invalid?).to be(false)
        expect(argument.content).to eq(community.community_id)
      end

      it "returns the auto-filled community ID" do
        # You can omit the community ID
        argument.store("", command)

        expect(argument.invalid?).to be(false)
        expect(argument.content).to eq(community.community_id)
      end

      it "returns the user's default if nothing was provided" do
        command.current_user.id_defaults.update!(community: community)

        argument.store("", command)

        expect(argument.invalid?).to be(false)
        expect(argument.content).to eq(community.community_id)
      end

      it "returns nil if not in a text channel and nothing was provided" do
        command.event = pm_event

        argument.store("", command)

        expect(argument.invalid?).to be(false)
        expect(argument.content).to be(nil)
      end
    end

    describe "server_id modifier" do
      let!(:argument) { described_class.new(:server_id, {}) }

      # No content was provided for server_id
      it "returns the community's channel default if in a text channel and nothing was provided" do
        # Channel takes precedence over the global
        community.id_defaults.create!(server: second_server)
        community.id_defaults.create!(server: server, channel_id: text_event.channel.id.to_s)

        argument.store("", command)

        expect(argument.invalid?).to be(false)
        expect(argument.content).to eq(server.server_id)
      end

      it "returns the community's global default if in a text channel and nothing was provided" do
        community.id_defaults.create!(server: second_server)

        argument.store("", command)

        expect(argument.invalid?).to be(false)
        expect(argument.content).to eq(second_server.server_id)
      end

      it "returns the user's default if nothing was provided" do
        command.current_user.id_defaults.update!(server: server)

        argument.store("", command)

        expect(argument.invalid?).to be(false)
        expect(argument.content).to eq(server.server_id)
      end

      it "returns nil if not in a text channel and nothing was provided" do
        command.event = pm_event

        argument.store("", command)

        expect(argument.invalid?).to be(false)
        expect(argument.content).to be(nil)
      end

      # Content was provided for server_id
      it "returns the existing content because the user provided a complete server_id" do
        argument.store(server.server_id, command)
        expect(argument.invalid?).to be(false)
        expect(argument.content).to eq(server.server_id)
      end

      it "returns the user's alias" do
        command.current_user.id_aliases.create!(server: server, value: "a")

        argument.store("a", command)
        expect(argument.invalid?).to be(false)
        expect(argument.content).to eq(server.server_id)
      end

      it "returns the auto-filled community section because the server section was provided" do
        # Using the server_name part of the server_id
        argument.store(server.server_id.split("_").second, command)

        expect(argument.invalid?).to be(false)
        expect(argument.content).to eq(server.server_id)
      end
    end
  end
end
