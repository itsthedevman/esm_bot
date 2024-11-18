# frozen_string_literal: true

describe ESM::Event::SendXm8Notification, :requires_connection do
  include_context "connection"

  let!(:second_user) { ESM::Test.user }

  let!(:territory_moderators) { [second_user.steam_uid] }

  before do
    second_user.exile_account
    territory.create_flag
  end

  it "works" do
    result = execute_sqf! <<~SQF
      private _territory = #{territory.id} call ESMs_system_territory_get;

      _territory call ExileServer_system_xm8_sendBaseRaid
    SQF

    # user = ESM::Test.user
    # second_user = ESM::Test.user
    # user.exile_account
    # second_user.exile_account
    # server = ESM::Test.server(for: ESM::Test.community)
    # owner_uid = user.steam_uid
    # territory = create(
    #   :exile_territory,
    #   owner_uid: owner_uid,
    #   moderators: [owner_uid],
    #   build_rights: [owner_uid],
    #   server_id: server.id
    # )

    # create(:exile_xm8_notification, recipient_uid: owner_uid)
    # create(:exile_xm8_notification, recipient_uid: second_user.steam_uid, content: {title: "Fuk"}.to_json)
    # create(:exile_xm8_notification, recipient_uid: owner_uid, type: "base-raid", content: {territory_id: territory.encoded_id, territory_name: territory.name}.to_json, territory_id: territory.id)
    # create(:exile_xm8_notification, recipient_uid: second_user.steam_uid, type: "base-raid", content: {territory_id: territory.encoded_id, territory_name: territory.name}.to_json, territory_id: territory.id)
    sleep 9999999
  end

  context "when the notification type is base-raid"
  context "when the notification type is charge-plant-started"
  context "when the notification type is custom"
  context "when the notification type is flag-restored"
  context "when the notification type is flag-steal-started"
  context "when the notification type is flag-stolen"
  context "when the notification type is grind-started"
  context "when the notification type is hack-started"
  context "when the notification type is marxet-item-sold"
  context "when the notification type is protection-money-due"
  context "when the notification type is protection-money-paid"
end
