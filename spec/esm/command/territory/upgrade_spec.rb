# frozen_string_literal: true

describe ESM::Command::Territory::Upgrade, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      let(:territory_id) { Faker::Alphanumeric.alphanumeric(number: 3..30) }

      context "when the territory can be upgraded" do
        it "is upgraded to the next level" do
          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, territory_id: territory_id})
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed.description).to eq("Hey #{user.mention}, you successfully upgraded territory `#{territory_id}` for **#{response.cost.to_poptab}**.\nYour territory has reached level **#{response.level}** and now has a radius of **#{response.range}** meters.\nAfter this transaction, you have **#{response.locker.to_poptab}** left in your locker.")
        end
      end
    end
  end

  describe "V2", category: "command", v2: true do
    it "is a player command" do
      expect(command.type).to eq(:player)
    end

    it "requires registration" do
      expect(command.registration_required?).to be(true)
    end

    describe "#on_execute", requires_connection: true do
      include_context "connection"

      let!(:territory) do
        owner_uid = ESM::Test.steam_uid
        create(
          :exile_territory,
          owner_uid: owner_uid,
          moderators: [owner_uid, user.steam_uid],
          build_rights: [owner_uid, user.steam_uid],
          server_id: server.id,
          level: 0
        )
      end

      before do
        user.exile_account.update!(locker: 1_000_000) # Aww yea
        territory.create_flag
      end

      context "when the player is online, is a moderator, and upgrades the territory" do
        it "upgrades the territory using poptabs from the player's locker" do
          execute!(arguments: {territory_id: territory.encoded_id, server_id: server.server_id})

          wait_for { ESM::Test.messages.size }.to eq(2)

          # Player response
          expect(
            ESM::Test.messages.retrieve(
              "`#{territory.encoded_id}` has been upgraded to level #{territory.level + 1}"
            )
          ).not_to be(nil)

          # Admin log
          expect(
            ESM::Test.messages.retrieve("Territory upgraded to level #{territory.level + 1}")
          ).not_to be(nil)
        end
      end

      context "when the player is offline, is a moderator, and upgrades the territory" do
        it "upgrades the territory using poptabs from the player's locker"
      end

      context "when the player is a territory admin" do
        it "upgrades the territory"
      end

      context "when there is tax on the upgrade" do
        it "includes the tax in the price"
      end

      context "when the player has not joined the server" do
        it "raises PlayerNeedsToJoin"
      end

      context "when the territory is null" do
        it "raises NullFlag and NullFlag_Admin"
      end

      context "when the player does not have permissions to upgrade" do
        it "raises MissingTerritoryAccess and MissingTerritoryAccess_Admin"
      end

      context "when the flag has been stolen" do
        it "raises Upgrade_StolenFlag"
      end

      context "when the flag is already at max level" do
        it "raise Upgrade_MaxLevel"
      end

      context "when the player is online and does not have enough poptabs" do
        it "raises Upgrade_TooPoor"
      end

      context "when the player is not online and does not have enough poptabs" do
        it "raises Upgrade_TooPoor"
      end
    end
  end
end
