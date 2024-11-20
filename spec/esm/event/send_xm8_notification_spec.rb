# frozen_string_literal: true

describe ESM::Event::SendXm8Notification, :requires_connection do
  include_context "connection"

  let!(:second_user) { ESM::Test.user }
  let!(:territory_owner) { user.steam_uid }
  let!(:territory_moderators) { [second_user.steam_uid] }

  let(:recipient_uids) { [user.steam_uid, second_user.steam_uid] }
  let(:notification_state_details) { "direct message" }
  let(:notification_content) do
    {
      territory_id: territory.encoded_id,
      territory_name: territory.name
    }.stringify_keys
  end

  let(:notification_sqf) do
    <<~SQF
      private _territory = #{territory.id} call ESMs_system_territory_get;
      _territory call #{xm8_sqf_function}
    SQF
  end

  subject(:trigger_notification) { execute_sqf!(notification_sqf) }

  let(:notification_type) {}
  let(:xm8_sqf_function) {}

  before do
    second_user.exile_account
    territory.create_flag
  end

  shared_examples "sends" do
    it "is expected to send the notification and update the server's database" do
      trigger_notification

      # Check outbound messages
      wait_for { ESM::Test.messages.size }.to eq(recipient_uids.size)

      # Check database update
      notifications = ESM::ExileXm8Notification.where(state: "sent")
      wait_for { notifications.size }.to eq(recipient_uids.size)

      notifications.each do |notification|
        expect(notification.recipient_uid).to be_in(recipient_uids)

        # These don't have a territory ID
        if !["custom", "marxet-item-sold"].include?(notification_type)
          expect(notification.territory_id).to eq(territory.id)
        end

        expect(notification.type).to eq(notification_type)
        expect(notification.content).to match(notification_content)
        expect(notification.state_details).to eq(notification_state_details)
        expect(notification.acknowledged_at).not_to be(nil)
      end
    end
  end

  context "when the notification type is base-raid" do
    let(:notification_type) { "base-raid" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendBaseRaid" }

    include_examples "sends"
  end

  context "when the notification type is charge-plant-started" do
    let(:notification_type) { "charge-plant-started" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendChargePlantStarted" }

    include_examples "sends"
  end

  context "when the notification type is flag-restored" do
    let(:notification_type) { "flag-restored" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendFlagRestored" }

    include_examples "sends"
  end

  context "when the notification type is flag-steal-started" do
    let(:notification_type) { "flag-steal-started" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendFlagStealStarted" }

    include_examples "sends"
  end

  context "when the notification type is flag-stolen" do
    let(:notification_type) { "flag-stolen" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendFlagStolen" }

    include_examples "sends"
  end

  context "when the notification type is grind-started" do
    let(:notification_type) { "grind-started" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendGrindingStarted" }

    include_examples "sends"
  end

  context "when the notification type is hack-started" do
    let(:notification_type) { "hack-started" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendHackingStarted" }

    include_examples "sends"
  end

  context "when the notification type is protection-money-due" do
    let(:notification_type) { "protection-money-due" }
    let(:notification_sqf) { "call ExileServer_system_xm8_sendProtectionMoneyDue" }

    before do
      territory.update!(last_paid_at: 20.days.ago, xm8_protectionmoney_notified: false)
    end

    include_examples "sends"
  end

  context "when the notification type is protection-money-paid" do
    let(:notification_type) { "protection-money-paid" }
    let(:xm8_sqf_function) { "ExileServer_system_xm8_sendProtectionMoneyPaid" }

    include_examples "sends"
  end

  context "when the notification type is custom" do
    let(:notification_type) { "custom" }
    let(:notification_content) do
      hash = embed_data.to_h
      hash["fields"] = be_a(String)
      hash
    end

    let(:embed_data) do
      ESM::Arma::HashMap.new(
        title: "This is a title",
        description: "This is a description",
        fields: [
          {name: "field title", value: "field value", inline: true}
        ]
      )
    end

    let(:notification_sqf) do
      <<~SQF
        [#{recipient_uids.to_json}, #{embed_data.to_json}] call ExileServer_system_xm8_sendCustom
      SQF
    end

    include_examples "sends"

    context "when the embed data is valid" do
      it "includes title, description, fields, etc." do
        trigger_notification

        # Check outbound messages
        wait_for { ESM::Test.messages.size }.to eq(recipient_uids.size)

        # For timing to ensure everything completes
        notifications = ESM::ExileXm8Notification.where(state: "sent")
        wait_for { notifications.size }.to eq(recipient_uids.size)

        embed = ESM::Test.messages.first.content
        expect(embed.title).to eq(embed_data[:title])
        expect(embed.description).to eq(embed_data[:description])
        embed.fields.zip(embed_data[:fields]).each do |embed_field, input_field|
          expect(embed_field.name).to eq(input_field[:name])
          expect(embed_field.value).to eq(input_field[:value])
          expect(embed_field.inline).to eq(input_field[:inline])
        end
      end
    end

    context "when the embed data is not valid" do
      let(:embed_data) { [] }

      it "logs a message to the server and discord" do
        trigger_notification

        wait_for { ESM::Test.messages.size }.to eq(1)
        message = ESM::Test.messages.first.content
        expect(message).to match("has encountered an error")
      end
    end
  end

  context "when the notification type is marxet-item-sold"
  context "when the notification type is invalid"
  context "when the notification has unregistered users"
  context "when the notification has no recipients"
  context "when the notification fails to send"
  context "when the recipients have custom routes"
end
