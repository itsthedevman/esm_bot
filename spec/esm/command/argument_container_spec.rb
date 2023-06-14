# frozen_string_literal: true

describe ESM::Command::ArgumentContainer do
  include_context "command"

  context "parses and stores the text with respect to its case" do
    let(:command_class) { ESM::Command::Test::ArgumentPreserveCase }

    specify do
      execute!(input: "Hello World!")
      expect(command.arguments.input).to eq("Hello World!")
    end
  end

  context "parses and stores the text as lowercase" do
    let(:command_class) { ESM::Command::Test::ArgumentIgnoreCase }

    specify do
      execute!(input: "Hello World!")
      expect(command.arguments.input).to eq("hello world!")
    end
  end

  context "raises an error with an embed when an required argument is missing" do
    let(:command_class) { ESM::Command::Test::ArgumentRequired }

    specify do
      expect { execute!(fail_on_raise: false) }.to raise_error(ESM::Exception::FailedArgumentParse) do |error|
        embed = error.data

        expect(embed.title).to eq("**Missing argument `<input>` for `~argument_required`**")
        expect(embed.description).to eq("```~argument_required <input>```")

        argument_field = embed.fields.first
        expect(argument_field.name).to eq("Arguments:")
        expect(argument_field.value).to eq("**`<input>`**\nThis argument is required.")

        expect(embed.footer.text).to eq("For more information, send me `~help argument_required`")
      end
    end
  end

  context "parses and type casts the value" do
    let(:command_class) { ESM::Command::Test::ArgumentTypeCast }

    it "to string, integer, float, json, and symbol" do
      execute!(
        string: "String Argument",
        integer: "1",
        float: "2.4443",
        json: {foo: true, bar: [1, 2, 3]}.to_json,
        symbol: "symbol_argument"
      )

      expect(command.arguments.string).to eq("string argument")
      expect(command.arguments.integer).to eq(1)
      expect(command.arguments.float).to eq(2.4443)
      expect(command.arguments.json).to eq({foo: true, bar: [1, 2, 3]})
      expect(command.arguments.symbol).to eq(:symbol_argument)
    end
  end

  context "parses and does not use the default because there was a value provided" do
    let(:command_class) { ESM::Command::Test::ArgumentDefault }

    specify do
      execute!(input: "success from input!") # input argument provided, no default
      expect(command.arguments.input).to eq("success from input!")
    end
  end

  context "parses and uses the default because no value was provided" do
    let(:command_class) { ESM::Command::Test::ArgumentDefault }

    specify do
      execute! # input argument not provided, use default
      expect(command.arguments.input).to eq("default success!")
    end
  end

  context "properly extracts command aliases when parsing" do
    let(:command_class) { ESM::Command::Test::ArgumentAlias }

    specify do
      # The bot will not find the command if this alias does not exist
      execute!(command_name: "alias_argument")
    end
  end

  context "returns all command argument descriptions" do
    let(:command_class) { ESM::Command::Test::ArgumentDescriptions }

    specify "and are valid" do
      expect(command.arguments.to_s).to eq(command.argument_descriptions)
    end
  end

  describe "#to_h" do
    let(:command_class) { ESM::Command::Test::ArgumentTypeCast }

    specify "converts correctly" do
      execute!(
        string: "String Argument",
        integer: "1",
        float: "2.4443",
        json: {foo: true, bar: [1, 2, 3]}.to_json,
        symbol: "symbol_argument"
      )

      hash = command.arguments.to_h
      expect(hash.keys).to match_array([:string, :integer, :float, :json, :symbol])
      expect(hash.values).to match_array([
        "string argument",
        1,
        2.4443,
        {foo: true, bar: [1, 2, 3]},
        :symbol_argument
      ])
    end
  end

  describe "#clear!" do
    let(:command_class) { ESM::Command::Test::ArgumentTypeCast }

    specify do
      execute!(
        string: "String Argument",
        integer: "1",
        float: "2.4443",
        json: {foo: true, bar: [1, 2, 3]}.to_json,
        symbol: "symbol_argument"
      )

      expect(command.arguments.map(&:content).reject(&:nil?)).not_to be_empty
      command.arguments.clear!
      expect(command.arguments.map(&:content).reject(&:nil?)).to be_empty
    end
  end
end
