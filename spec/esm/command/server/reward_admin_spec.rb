# frozen_string_literal: true

describe ESM::Command::Server::RewardAdmin, category: "command", v2: true do
  include_context "command", described_class
  include_examples "validate_command"

  let(:target) { second_user.mention }
  let(:type) { described_class::POPTAB }
  let(:classname) {}
  let(:amount) { Faker::Number.positive.to_i }
  let(:expires_in) { "never" }
  let(:prompt_response) { true }

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
    let(:reward_query) do
      {
        reward_type: type,
        amount:,
        source: "command_reward_admin"
      }
    end

    it "adds the reward" do
      expect(ESM::ExileReward.all.size).to eq(0)

      execute_command

      wait_for { ESM::Test.messages.size }.to be >= 2

      embed = ESM::Test.messages.retrieve("Please review the reward details below")&.content
      expect(embed).not_to be(nil)

      matcher =
        case type
        when described_class::POPTAB
          "#{amount.to_delimitated_s} poptabs"
        when described_class::RESPECT
          "#{amount.to_delimitated_s} respect"
        when described_class::CLASSNAME
          display_name = ESM::Arma::ClassLookup.find(classname).display_name
          "#{display_name} (x#{amount.to_delimitated_s})"
        end

      expect(embed.description).to include(matcher)
      expect(ESM::Test.messages.retrieve("Reward has been added")).not_to be(nil)

      expect(ESM::ExileReward.where(reward_query).size).to eq(1)
    end
  end

  #####################################

  before do
    user.exile_account
    second_user.exile_account

    grant_command_access!(community, "reward_admin")
  end

  it "is an admin command" do
    expect(command.type).to eq(:admin)
  end

  it "has an allowlist enabled" do
    expect(command.attributes.allowlist_enabled.default).to be(true)
  end

  it "is limited to text channels" do
    expect(command.limited_to).to eq(:text)
  end

  describe "#on_execute", requires_connection: true do
    include_context "connection"

    context "when the target is a steam uid" do
      let(:target) do
        steam_uid = second_user.steam_uid
        second_user.update!(steam_uid: nil)

        steam_uid
      end

      include_examples "success"
    end

    context "when the type is poptabs" do
      context "and the amount is valid" do
        include_examples "success"
      end

      context "and the amount is invalid" do
        let(:amount) { -1 }

        include_examples "raises_check_failure" do
          let(:matcher) { "A positive amount is required" }
        end
      end
    end

    context "when the type is respect" do
      let(:type) { described_class::RESPECT }

      context "and the amount is valid" do
        include_examples "success"
      end

      context "and the amount is invalid" do
        let(:amount) { -1 }

        include_examples "raises_check_failure" do
          let(:matcher) { "A positive amount is required" }
        end
      end
    end

    context "when the type is item/vehicle" do
      let(:type) { described_class::CLASSNAME }

      context "and the item/vehicle is valid" do
        let(:classname) { ESM::Arma::ClassLookup.where(mod: "exile").keys.sample }

        context "and the amount if valid" do
          include_examples "success" do
            let!(:reward_query) do
              {
                reward_type: type,
                amount:,
                classname:,
                source: "command_reward_admin"
              }
            end
          end
        end

        context "and the amount is invalid" do
          let(:amount) { -1 }

          include_examples "raises_check_failure" do
            let(:matcher) { "A positive amount is required" }
          end
        end
      end

      context "and the item/vehicle is invalid" do
        # Test server does not CUP installed
        let(:classname) { ESM::Arma::ClassLookup.where(mod: "cup").keys.sample }

        include_examples "raises_check_failure" do
          let(:matcher) { "`#{classname}` is not a valid classname" }
        end
      end
    end

    context "when the expires time is never" do
      include_examples "success" do
        let!(:reward_query) do
          {
            reward_type: type,
            expires_at: nil
          }
        end
      end
    end

    context "when the expires time is a valid format" do
      let(:expires_in) { "1 day" }

      include_examples "success" do
        let!(:reward_query) do
          {
            reward_type: type,
            expires_at: 1.day.from_now
          }
        end
      end
    end

    context "when the expires time is invalid" do
      let(:expires_in) { "gibberish" }

      include_examples "raises_check_failure" do
        let!(:matcher) { "`#{expires_in}` is not a valid expiration time" }
      end
    end

    context "when the logging is enabled" do
      before do
        server.server_setting.update!(logging_reward_admin: true)
      end

      include_examples "arma_discord_logging_enabled" do
        let(:message) { "`/server admin reward` executed successfully" }
        let(:fields) { [target_field.merge(name: "Player")] }
      end
    end

    context "when the logging is disabled", :current do
      before do
        server.server_setting.update!(logging_reward_admin: false)
      end

      include_examples "arma_discord_logging_disabled" do
        let(:message) { "`/server admin reward` executed successfully" }
      end
    end
  end
end
