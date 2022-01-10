# frozen_string_literal: true

describe ESM::Event::ServerInitialization, v2: true, requires_connection: true do
  include_examples "connection"

  let(:community) { ESM::Test.community }
  let(:server) { ESM::Test.server }
  let(:user) { ESM::Test.user(:with_role) }
  let(:setting) { server.server_setting }
  let(:reward) { server.server_reward }

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
          [["level", "purchase_price", "radius", "object_count"], [1, 5000, 15, 30]],
          [["level", "purchase_price", "radius", "object_count"], [2, 10_000, 30, 60]],
          [["level", "purchase_price", "radius", "object_count"], [3, 15_000, 45, 90]],
          [["level", "purchase_price", "radius", "object_count"], [4, 20_000, 60, 120]],
          [["level", "purchase_price", "radius", "object_count"], [5, 25_000, 75, 150]],
          [["level", "purchase_price", "radius", "object_count"], [6, 30_000, 90, 180]],
          [["level", "purchase_price", "radius", "object_count"], [7, 35_000, 105, 210]],
          [["level", "purchase_price", "radius", "object_count"], [8, 40_000, 120, 240]],
          [["level", "purchase_price", "radius", "object_count"], [9, 45_000, 135, 270]],
          [["level", "purchase_price", "radius", "object_count"], [10, 50_000, 150, 300]]
        ].to_json,
        server_start_time: Time.now.utc.to_s,
        vg_enabled: true,
        vg_max_sizes: "[\"-1\",\"5\",\"8\",\"11\",\"13\",\"15\",\"18\",\"21\",\"25\",\"28\"]"
      }
    )
  end

  let(:event) { described_class.new(connection, message) }

  before :each do
    ESM::Test.block_outbound_messages = true

    # Update the data stored in the connection object, NOT the one in the test.
    connection.server.community.update!(territory_admin_ids: [user.role_id.to_s])
    connection.server.server_setting.update!(extdb_path: Faker::File.dir, logging_path: Faker::File.dir)

    expect do
      message = event.run!
      message.run_callback(:on_response, nil, nil)
    end.not_to raise_error

    server.reload

    # Clear the message sent from the event
    ESM::Connection::Server.instance.message_overseer.remove_all!
  end

  it "updates the server" do
    expect(server.server_name).to eq(message.data.server_name)
    expect(server.server_start_time).to eq(message.data.server_start_time)
  end

  it "updates the server settings" do
    expect(setting.territory_price_per_object).to eq(message.data.price_per_object)
    expect(setting.territory_lifetime).to eq(message.data.territory_lifetime)
  end

  it "creates territories" do
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

  it "settings data is valid" do
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
