# frozen_string_literal: true

describe ESM::Command::Argument do
  describe "Valid Argument" do
    let(:argument) do
      container = ESM::Command::ArgumentContainer.new([[:foo, { regex: /foo/, description: "Test" }]])
      container.first
    end

    it "should be a valid argument" do
      expect(argument).not_to be_nil
    end

    it "should have regex" do
      expect(argument.regex).not_to be_nil
      expect(argument.regex.source).to eq("(foo)")
    end
  end

  describe "Invalid Argument (missing regex)" do
    it "should raise error" do
      expect { ESM::Command::ArgumentContainer.new([[:foo, {}]]) }.to raise_error("Missing regex for argument :foo")
    end
  end

  describe "Invalid Argument (missing description)" do
    it "should raise error" do
      expect { ESM::Command::ArgumentContainer.new([[:foo, { regex: /woot/ }]]) }.to raise_error("Missing description for argument :foo")
    end
  end

  describe "Display Name Argument" do
    let(:argument) do
      container = ESM::Command::ArgumentContainer.new([[:foo, { regex: /foo/, display_as: "FOOBAR", description: "Test" }]])
      container.first
    end

    it "should have a different display name" do
      expect(argument.display_as).not_to be_nil
      expect(argument.display_as).to eq("FOOBAR")
      expect(argument.name).not_to eq(argument.display_as)
    end
  end

  describe "Type Argument" do
    let(:argument) do
      container = ESM::Command::ArgumentContainer.new([[:foo, { regex: /12345/, type: :integer, description: "Test" }]])
      container.first
    end

    it "should be a integer" do
      expect(argument.type).to eq(:integer)
    end
  end

  describe "Case Preserved Argument" do
    let(:argument) do
      container = ESM::Command::ArgumentContainer.new([[:foo, { regex: /Foo/, preserve: true, description: "Test" }]])
      container.first
    end

    it "should preserve it's case" do
      expect(argument.preserve_case?).to be(true)
    end
  end

  describe "Mutliline Argument" do
    let(:argument) do
      container = ESM::Command::ArgumentContainer.new([[:foo, { regex: /[\s\S]+/, multiline: true, description: "Test" }]])
      container.first
    end

    it "should be multiline" do
      expect(argument.multiline?).to be(true)
    end
  end

  describe "Default Argument" do
    let(:argument) do
      container = ESM::Command::ArgumentContainer.new([[:foo, { regex: /hello/, default: "Hello World", description: "Test" }]])
      container.first
    end

    it "should have a default value" do
      expect(argument.default?).to be(true)
      expect(argument.default).to eq("Hello World")
    end

    it "should not be required" do
      expect(argument.required?).to be(false)
    end
  end

  describe "Description Argument" do
    let(:argument) do
      container = ESM::Command::ArgumentContainer.new([[:foo, { regex: /hello/, description: "test" }]])
      container.first
    end

    it "should have a description" do
      expect(argument.description).to eq("This is a test")
    end
  end

  describe "Argument with default values" do
    let(:argument) do
      container = ESM::Command::ArgumentContainer.new([[:foo, { regex: /.+/, description: "test" }]])
      container.first
    end

    it "should not preserve case" do
      expect(argument.preserve_case?).to be(false)
    end

    it "should be required" do
      expect(argument.required?).to be(true)
    end

    it "should be a string" do
      expect(argument.type).to eq(:string)
    end

    it "should have a display name" do
      expect(argument.display_as).to eq("foo")
    end

    it "should have a nil default" do
      expect(argument.default).to be_nil
    end

    it "should not have a default" do
      expect(argument.default?).to be(false)
    end

    it "should have a description" do
      expect(argument.description).to eq("This is a test")
    end
  end

  describe "#to_s" do
    it "should be a standard argument" do
      container = ESM::Command::ArgumentContainer.new([[:foo, { regex: /.+/, description: "test" }]])
      argument = container.first
      expect(argument.to_s).to eq("<foo>")
    end

    it "should be an optional argument" do
      container = ESM::Command::ArgumentContainer.new([[:foo, { regex: /.+/, default: "foobar", description: "test" }]])
      argument = container.first
      expect(argument.to_s).to eq("<?foo>")
    end

    it "should use the display_as" do
      container = ESM::Command::ArgumentContainer.new([[:foo, { regex: /.+/, display_as: "bar", description: "test" }]])
      argument = container.first
      expect(argument.to_s).to eq("<bar>")
    end
  end

  describe "Arugment with template name" do
    it "should get defaults" do
      container = ESM::Command::ArgumentContainer.new([[:server_id, {}]])
      argument = container.first
      expect(argument.regex).to eq(Regexp.new("(#{ESM::Regex::SERVER_ID_OPTIONAL_COMMUNITY.source})", Regexp::IGNORECASE))
      expect(argument.description).not_to be_blank
    end
  end

  describe "Argument with template keyword" do
    it "should get defaults" do
      container = ESM::Command::ArgumentContainer.new([[:some_other_argument, { template: :server_id }]])
      argument = container.first
      expect(argument.name).to eq(:some_other_argument)
      expect(argument.regex).to eq(Regexp.new("(#{ESM::Regex::SERVER_ID_OPTIONAL_COMMUNITY.source})", Regexp::IGNORECASE))
      expect(argument.description).not_to be_blank
    end
  end

  describe "#parse" do
    let!(:community) { ESM::Test.community }
    let!(:server) { ESM::Test.server }
    let!(:user) { ESM::Test.user }
    let!(:command) { ESM::Command::Test::CommunityAndServerCommand.new }
    let!(:command_statement) { command.statement }
    let!(:event) { CommandEvent.create(command_statement, user: user, channel_type: :text) }

    before :each do
      command.event = event
    end

    it "should autofill (server_id)" do
      container = ESM::Command::ArgumentContainer.new([[:server_id, {}]])
      argument = container.first

      # Using the server_name part of the server_id
      argument.parse(command, server.server_id.split("_").second)

      expect(argument.invalid?).to be(false)
      expect(argument.value).to eq(server.server_id)
    end

    it "should autofill (community_id)" do
      container = ESM::Command::ArgumentContainer.new([[:community_id, {}]])
      argument = container.first

      # You can omit the community ID
      argument.parse(command, "")

      expect(argument.invalid?).to be(false)
      expect(argument.value).to eq(community.community_id)
    end
  end
end
