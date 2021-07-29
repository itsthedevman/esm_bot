# frozen_string_literal: true

describe ESM::Event::ServerInitialization do
  # This has to be esm_community for roles
  let!(:community) { create(:esm_community, territory_admin_ids: ["440254072780488714", "440296219726708747"]) }
  let!(:server) { create(:server, community_id: community.id) }
  let!(:user) { create(:user) }
  let(:reward) { server.server_reward }
  let(:setting) { server.server_setting }

  describe "#run!" do
    let(:connection) { ESM::Connection.new(ESM::Connection::Server.instance, server.server_id) }
    let(:event) { described_class.new(connection, message) }
    let(:message) do
      ESM::Connection::Message.new(
        type: "init",
        data_type: "init",
        data: {
          server_name: Faker::Commerce.product_name,
          price_per_object: Faker::Number.between(from: 0, to: 1_000_000_000),
          territory_lifetime: Faker::Number.between(from: 0, to: 1_000),
          territory_data: [
            [["level", 1], ["purchase_price", 5000], ["radius", 15], ["object_count", 30]],
            [["level", 2], ["purchase_price", 10_000], ["radius", 30], ["object_count", 60]],
            [["level", 3], ["purchase_price", 15_000], ["radius", 45], ["object_count", 90]],
            [["level", 4], ["purchase_price", 20_000], ["radius", 60], ["object_count", 120]],
            [["level", 5], ["purchase_price", 25_000], ["radius", 75], ["object_count", 150]],
            [["level", 6], ["purchase_price", 30_000], ["radius", 90], ["object_count", 180]],
            [["level", 7], ["purchase_price", 35_000], ["radius", 105], ["object_count", 210]],
            [["level", 8], ["purchase_price", 40_000], ["radius", 120], ["object_count", 240]],
            [["level", 9], ["purchase_price", 45_000], ["radius", 135], ["object_count", 270]],
            [["level", 10], ["purchase_price", 50_000], ["radius", 150], ["object_count", 300]]
          ].to_json,
          server_start_time: Time.now.utc.to_s
        },
        convert_types: true
      )
    end

    before :each do
      expect { event.run! }.not_to raise_error
    end

    it "should valid" do
      expect(event).not_to be_nil
    end

    describe "#initialize_server!" do
      before :each do
        server.reload
      end

      it "should have updated the server" do
        expect(server.server_name).to eq(message.data.server_name)
        expect(server.server_start_time).to eq(message.data.server_start_time)
      end

      it "should have updated the server settings" do
        settings = server.server_setting

        expect(settings.territory_price_per_object).to eq(message.data.price_per_object)
        expect(settings.territory_lifetime).to eq(message.data.territory_lifetime)
      end

      it "should have created territories" do
        expect(ESM::Territory.where(server_id: server.id).size).to eq(10)

        message.data.territory_data.each do |territory_data|
          territory = ESM::Territory.where(server_id: server.id, territory_level: territory_data[:level]).first
          expect(territory).not_to be_nil
          expect(territory.territory_level).to eq(territory_data[:level])
          expect(territory.territory_purchase_price).to eq(territory_data[:purchase_price])
          expect(territory.territory_radius).to eq(territory_data[:radius])
          expect(territory.territory_object_count).to eq(territory_data[:object_count])
        end
      end
    end

    describe "#build_setting_data" do
      before :each do
        server.reload
        setting.reload
        reward.reload
      end

      it "should be valid" do
        expect(event.data.territory_admins).to eq([user.steam_uid])
        expect(event.data.extdb_path).to eq(setting.extdb_path || "")
        expect(event.data.gambling_modifier).to eq(setting.gambling_modifier)
        expect(event.data.gambling_payout).to eq(setting.gambling_payout)
        expect(event.data.gambling_randomizer_max).to eq(setting.gambling_randomizer_max)
        expect(event.data.gambling_randomizer_mid).to eq(setting.gambling_randomizer_mid)
        expect(event.data.gambling_randomizer_min).to eq(setting.gambling_randomizer_min)
        expect(event.data.gambling_win_chance).to eq(setting.gambling_win_chance)
        expect(event.data.logging_add_player_to_territory).to eq(setting.logging_add_player_to_territory)
        expect(event.data.logging_demote_player).to eq(setting.logging_demote_player)
        expect(event.data.logging_exec).to eq(setting.logging_exec)
        expect(event.data.logging_gamble).to eq(setting.logging_gamble)
        expect(event.data.logging_modify_player).to eq(setting.logging_modify_player)
        expect(event.data.logging_pay_territory).to eq(setting.logging_pay_territory)
        expect(event.data.logging_promote_player).to eq(setting.logging_promote_player)
        expect(event.data.logging_remove_player_from_territory).to eq(setting.logging_remove_player_from_territory)
        expect(event.data.logging_reward).to eq(setting.logging_reward)
        expect(event.data.logging_transfer).to eq(setting.logging_transfer)
        expect(event.data.logging_upgrade_territory).to eq(setting.logging_upgrade_territory)
        expect(event.data.max_payment_count).to eq(setting.max_payment_count)
        expect(event.data.territory_payment_tax).to eq(setting.territory_payment_tax / 100)
        expect(event.data.territory_upgrade_tax).to eq(setting.territory_upgrade_tax / 100)

        # TODO: REWARDS
        # expect(event.data.reward_player_poptabs).to eq(reward.player_poptabs)
        # expect(event.data.reward_locker_poptabs).to eq(reward.locker_poptabs)
        # expect(event.data.reward_respect).to eq(reward.respect)
        # expect(event.data.reward_items).to eq("[[\"Exile_Item_EMRE\",2],[\"Chemlight_blue\",5]]")
      end
    end
  end
end
