# frozen_string_literal: true

describe ESM::Command::Territory::Pay, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      context "when the execution is valid" do
        it "returns a success message" do
          request = execute!(
            channel_type: :dm,
            arguments: {server_id: server.server_id, territory_id: Faker::Crypto.md5[0, 5]}
          )

          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed.description).to match(/has successfully received the payment/i)
        end
      end
    end
  end

  describe "V2", v2: true do
    it "is a player command" do
      expect(command.type).to eq(:player)
    end

    it "requires registration" do
      expect(command.registration_required?).to be(true)
    end

    describe "#on_execute", requires_connection: true do
      include_context "connection" do
        let!(:territory_moderators) { [user.steam_uid] }
      end

      let(:locker_balance) { 1_000_000 }  # Aww yea

      subject(:execute_command) do
        execute!(arguments: {territory_id: territory.encoded_id, server_id: server.server_id})
      end

      before do
        user.exile_account.update!(locker: locker_balance)
        territory.number_of_constructions = 15
        territory.create_flag
      end

      context "when the player has not joined the server" do
        before { user.exile_account.destroy! }

        include_examples "arma_error_player_needs_to_join"
      end

      context "when the territory is null" do
        before { territory.delete_flag }

        include_examples "arma_error_null_flag"
      end

      context "when the player is not a member of this territory" do
        before { territory.revoke_membership(user.steam_uid) }

        include_examples "arma_error_missing_territory_access"
      end

      context "when the flag has been stolen" do
        before { territory.update!(flag_stolen: true) }

        include_examples "arma_error_flag_stolen"
      end

      context "when the player is online and does not have enough poptabs" do
        let!(:locker_balance) { 0 }

        before { spawn_player_for(user) }

        include_examples "arma_error_too_poor"
      end

      context "when the player is not online and does not have enough poptabs" do
        let!(:locker_balance) { 0 }

        include_examples "arma_error_too_poor"
      end
    end
  end
end
