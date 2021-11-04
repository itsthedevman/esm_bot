# frozen_string_literal: true

describe ESM::Event::ServerInitialization, requires_connection: true do
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server }
  let!(:user) { ESM::Test.user }

  describe "#run!" do
    let(:setting) { server.server_setting }
    let(:reward) { server.server_reward }
    let(:connection) { server.connection }

    let!(:message) do
      ESM::Connection::Message.new(
        type: "init",
        data_type: "init",
        data: {
          extension_version: "2.0.0",
          server_name: server.server_name,
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
          server_start_time: Time.now.utc.to_s,
          vg_enabled: true,
          vg_max_sizes: "[\"-1\",\"5\",\"8\",\"11\",\"13\",\"15\",\"18\",\"21\",\"25\",\"28\"]"
        }
      )
    end

    let(:event) { described_class.new(connection, message) }

    before :each do
      wait_for { server.connected? }.to be(true)

      # This class sends an initialization message to the server and it will cause issues if sent twice
      allow(connection).to receive(:send_message)
      expect { event.run! }.not_to raise_error

      server.reload
    end

    describe "#initialize_server!" do
      it "updated the server" do
        expect(server.server_name).to eq(message.data.server_name)
        expect(server.server_start_time).to eq(message.data.server_start_time)
      end

      it "updated the server settings" do
        expect(setting.territory_price_per_object).to eq(message.data.price_per_object)
        expect(setting.territory_lifetime).to eq(message.data.territory_lifetime)
      end

      it "created territories" do
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
      it "is valid" do
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
      end
    end
  end
end
