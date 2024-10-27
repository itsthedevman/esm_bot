# frozen_string_literal: true

describe ESM::Xm8Notification do
  let(:linked_notifications) do
    {
      SecureRandom.uuid => ESM::Test.steam_uid,
      SecureRandom.uuid => ESM::Test.steam_uid,
      SecureRandom.uuid => ESM::Test.steam_uid
    }
  end

  subject(:notification) do
    described_class.new(
      uuids: linked_notifications.keys,
      recipient_uids: linked_notifications.values,
      content: {},
      created_at: Time.current
    )
  end

  describe ".from" do
    let(:type) {}
    let(:recipient_uids) { [ESM::Test.steam_uid] }
    let(:data) { {territory_name: Faker::String.random, territory_id: Faker::String.random} }

    let(:notification_hash) do
      {
        uuids: [SecureRandom.uuid],
        type:,
        recipient_uids:,
        content: data.to_json,
        created_at: Faker::Time.forward.strftime(ESM::Time::Format::SQL_TIME)
      }
    end

    subject(:notification) { described_class.from(notification_hash) }

    context "when content is valid" do
      let!(:type) { "base-raid" }

      it "is expected to convert the content to a hash" do
        expect(notification.content.to_h).to eq(data)
      end
    end

    context "when content is invalid" do
      let!(:type) { "foobar" }

      it "is expected to raise NameError" do
        expect { notification }.to raise_error(
          ESM::Xm8Notification::InvalidType, "\"foobar\" is not a valid XM8 notification type"
        )
      end
    end

    context "when the type is base-raid" do
      let!(:type) { "base-raid" }

      it { is_expected.to be_instance_of(described_class::BaseRaid) }
    end

    context "when the type is charge-plant-started" do
      let!(:type) { "charge-plant-started" }

      it { is_expected.to be_instance_of(described_class::ChargePlantStarted) }
    end

    context "when the type is custom" do
      let!(:type) { "custom" }
      let!(:data) { {title: Faker::String.random, description: Faker::String.random} }

      it { is_expected.to be_instance_of(described_class::Custom) }
    end

    context "when the type is flag-restored" do
      let!(:type) { "flag-restored" }

      it { is_expected.to be_instance_of(described_class::FlagRestored) }
    end

    context "when the type is flag-restored" do
      let!(:type) { "flag-restored" }

      it { is_expected.to be_instance_of(described_class::FlagRestored) }
    end

    context "when the type is flag-steal-started" do
      let!(:type) { "flag-steal-started" }

      it { is_expected.to be_instance_of(described_class::FlagStealStarted) }
    end

    context "when the type is flag-stolen" do
      let!(:type) { "flag-stolen" }

      it { is_expected.to be_instance_of(described_class::FlagStolen) }
    end

    context "when the type is grind-started" do
      let!(:type) { "grind-started" }

      it { is_expected.to be_instance_of(described_class::GrindStarted) }
    end

    context "when the type is hack-started" do
      let!(:type) { "hack-started" }

      it { is_expected.to be_instance_of(described_class::HackStarted) }
    end

    context "when the type is marxet-item-sold" do
      let!(:type) { "marxet-item-sold" }
      let!(:data) { {item_name: Faker::String.random, poptabs_received: Faker::String.random} }

      it { is_expected.to be_instance_of(described_class::MarxetItemSold) }
    end

    context "when the type is protection-money-due" do
      let!(:type) { "protection-money-due" }

      it { is_expected.to be_instance_of(described_class::ProtectionMoneyDue) }
    end

    context "when the type is protection-money-paid" do
      let!(:type) { "protection-money-paid" }

      it { is_expected.to be_instance_of(described_class::ProtectionMoneyPaid) }
    end
  end

  describe "#reject_unregistered_uids!" do
    let(:registered_uids) { linked_notifications.values }

    subject(:unregistered_uids) { notification.reject_unregistered_uids!(registered_uids) }

    context "when there are no unregistered UIDs" do
      it "removes nothing" do
        is_expected.to eq([])

        expect(notification.uuids).to eq(linked_notifications.keys)
        expect(notification.recipient_uids).to eq(linked_notifications.values)
      end
    end

    context "when there are unregistered UIDs" do
      let!(:registered_uids) { [linked_notifications.values.sample] }
      let!(:registered_uuid) { registered_uids.map { |uid| linked_notifications.key(uid) } }
      let!(:unregistered_uids) { linked_notifications.values - registered_uids }

      it "removes the unregistered UIDs and corresponding UUID" do
        is_expected.to eq(unregistered_uids)

        expect(notification.uuids).to eq(linked_notifications.keys)
        expect(notification.recipient_uids).to eq(linked_notifications.values)
      end
    end
  end
end
