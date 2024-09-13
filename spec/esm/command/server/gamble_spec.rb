# frozen_string_literal: true

describe ESM::Command::Server::Gamble, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      context "when the amount is a number" do
        it "gambles with the amount of poptabs on the server" do
          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "300"})

          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).not_to be_blank
          expect(embed.description).not_to be_blank
        end
      end

      context "when the amount is 'half'" do
        it "gambles half of the user's poptabs on the server" do
          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "half"})

          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).not_to be_blank
          expect(embed.description).not_to be_blank
        end
      end

      context "when the amount is 'all'" do
        it "gambles all of the players money" do
          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "all"})
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).not_to be_blank
          expect(embed.description).not_to be_blank
        end
      end

      context "when the user does not have enough poptabs" do
        it "returns an error from the server" do
          wsc.flags.NOT_ENOUGH_MONEY = true

          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "100000000"})
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed.description).to match(/not enough poptabs/i)
        end
      end

      context "when the amount is 0" do
        it "raises an exception" do
          execution_args = {channel_type: :dm, arguments: {server_id: server.server_id, amount: "0"}}

          expect { execute!(**execution_args) }.to raise_error(
            ESM::Exception::CheckFailure,
            /you simply cannot gamble nothing/
          )
        end
      end

      context "when the amount is negative" do
        it "raises an exception" do
          execution_args = {channel_type: :dm, arguments: {server_id: server.server_id, amount: "-1"}}

          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure)
        end
      end

      context "when the amount is 'stats'" do
        it "returns the gambling stats for the server" do
          execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "stats"})

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).to match("Gambling statistics")
          expect(embed.fields.size).to eq(14)
        end
      end

      context "when the amount is omitted" do
        it "returns the gambling stats for the server" do
          execute!(channel_type: :dm, arguments: {server_id: server.server_id})

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).to match("Gambling statistics")
          expect(embed.fields.size).to eq(14)
        end
      end
    end
  end

  describe "V2", v2: true do
    it "is a player command" do
      expect(command.type).to eq(:player)
    end

    describe "#on_execute", requires_connection: true do
      include_context "connection"

      let(:locker_balance) { 1_000_000 }  # Aww yea
      let(:amount) {}

      let(:server_setting_default) do
        {gambling_locker_limit_enabled: false}
      end

      let(:server_setting) { {} }

      subject(:execute_command) do
        execute!(arguments: {server_id: server.server_id, amount:})
      end

      ##########################################################################
      # Callbacks

      before do
        trace!("before")
        server.server_setting.update!(server_setting_default.merge(server_setting))
        user.exile_account.update!(locker: locker_balance)
      end

      ##########################################################################
      # Examples

      shared_examples "reply_with_stats" do
        it "is expected to reply back with the stats" do
          execute_command

          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.retrieve(
            "Gambling statistics for `#{server.server_id}`"
          )&.content

          expect(embed).not_to be(nil)

          expect(embed.fields.size).to eq(14)
        end
      end

      shared_examples "raise_bad_amount" do
        include_examples "raises_check_failure" do
          let(:message) { "I'm sorry #{user.mention}, but you simply cannot gamble nothing." }
        end
      end

      shared_examples "successful_gamble_win" do
        let!(:server_setting) { {gambling_win_percentage: 100} }

        it "is expected to gamble the amount and win"
      end

      shared_examples "successful_gamble_loss" do
        let!(:server_setting) { {gambling_win_percentage: 0} }
        let(:streak) { 1 }

        it "is expected to gamble the amount and lose" do
          execute_command

          wait_for { ESM::Test.messages.size }.to be > 1

          embed = ESM::Test.messages.retrieve("Better luck next time!")&.content
          expect(embed).not_to be(nil)
          expect(embed.description).not_to be_blank
          expect(embed.footer.text).to eq("Current Streak: #{streak}")
        end
      end

      ##########################################################################
      # Tests

      context "when the amount is omitted", requires_connection: false do
        include_examples "reply_with_stats"
      end

      context "when the amount is 'stats'", requires_connection: false do
        let!(:amount) { "stats" }

        include_examples "reply_with_stats"
      end

      context "when the server is not connected", requires_connection: false do
        context "and the stats are requested" do
          let!(:amount) { "stats" }

          include_examples "reply_with_stats"
        end

        context "and an amount is given" do
          let!(:amount) { 100 }

          include_examples "raises_server_not_connected"
        end
      end

      context "when the amount is negative" do
        let(:amount) { -1 }

        include_examples "raise_bad_amount"
      end

      context "when the amount is zero" do
        let(:amount) { 0 }

        include_examples "raise_bad_amount"
      end

      context "when the amount is a positive number" do
        let(:amount) { 50 }

        context "and the player is online" do
          # it "is expected to update the player's locker variable"
        end

        context "and the player is offline" do
          # it "is expected to update the player's locker database"
        end

        context "and the player loses" do
          include_examples "successful_gamble_loss"
        end

        context "and the player has a streak" do
          before do
            user.user_gamble_stats.first_or_initialize.update!(
              server:,
              current_streak: 1,
              last_action: described_class::LOSS_ACTION
            )
          end

          include_examples "successful_gamble_loss" do
            let(:streak) { 2 }
          end
        end
      end

      context "when the amount is 'all'" do
        it "is expected to gamble all of the player's locker"
      end

      context "when the amount is 'half'" do
        it "is expected to gamble half of the player's locker"
      end

      context "when logging is enabled" do
        before do
          server.server_setting.update!(logging_gamble_player: true)
        end

        include_examples "arma_discord_logging_enabled" do
          let(:message) { "`ESMs_command_gamble` executed successfully" }
        end
      end

      context "when logging is disabled" do
        before do
          server.server_setting.update!(logging_gamble_player: false)
        end

        include_examples "arma_discord_logging_disabled" do
          let(:message) { "`ESMs_command_gamble` executed successfully" }
        end
      end

      context "when the player is gambling more than what they have" do
        let!(:locker_balance) { 0 }

        include_examples "arma_error_too_poor"
      end

      context "when the locker limit is enabled" do
        context "and the player has too many poptabs in their locker"
        context "and the player will have too many poptabs after gambling"
      end
    end
  end
end
