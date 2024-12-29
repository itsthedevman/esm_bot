# frozen_string_literal: true

describe ESM::Command::Server::RewardAdmin, category: "command", v2: true do
  include_context "command", described_class
  include_examples "validate_command"

  let(:target) { user.mention }
  let(:type) { described_class::POPTAB }
  let(:classname) {}
  let(:amount) { Faker::Number.positive.to_i }
  let(:expires_in) { "never" }
  let(:prompt_response) {}

  let(:arguments) do
    {
      target:,
      server_id: server.server_id,
      type:,
      classname:,
      amount:,
      expires_in:
    }
  end

  subject(:execute_command) { execute!(arguments:, prompt_response:) }

  #####################################

  shared_examples "success" do
    it "adds the reward" do
      execute_command

      wait_for { ESM::Test.messages.size }.to be >= 2

      embed = ESM::Test.messages.retrieve("Please review the reward details below")&.content
      expect(embed).not_to be(nil)

      matcher =
        case type
        when described_class::POPTAB
          "#{amount} poptabs"
        when described_class::RESPECT
          "#{amount} respect"
        when described_class::CLASSNAME
          "#{classname} (x#{amount})"
        end

      expect(embed.description).to match(matcher)

      expect(
        ESM::Test.messages.retrieve("Reward has been added")
      ).not_to be(nil)
    end
  end

  #####################################

  before do
    user.exile_account
    second_user.exile_account
  end

  it "is an admin command" do
    expect(command.type).to eq(:admin)
  end

  describe "#on_execute", requires_connection: true do
    include_context "connection"

    context "when the target is a steam uid" do
      let(:prompt_response) { true }

      let(:target) do
        steam_uid = second_user.steam_uid
        second_user.update!(steam_uid: nil)

        steam_uid
      end

      include_examples "success"
    end

    context "when the target is a mention"

    context "when the type is poptabs"
    context "when the type is respect"
    context "when the type is item/vehicle"

    context "when the expires time is never"
    context "when the expires time is a valid format"
    context "when the expires time is invalid"

    context "when the logging is enabled"
    context "when the logging is disabled"
  end
end
