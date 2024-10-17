# frozen_string_literal: true

describe ESM::Xm8Notification do
  describe ".from" do
    let(:type) {}
    let(:recipient_uid) { ESM::Test.steam_uid }
    let(:data) { {territory_name: Faker::String.random, territory_id: Faker::String.random} }

    let(:notification_hash) do
      {
        id: Faker::Number.positive,
        type:,
        recipient_uid:,
        content: data.to_json,
        created_at: Faker::Time.forward.strftime(ESM::Time::Format::SQL_TIME)
      }
    end

    subject(:notification) { described_class.from(notification_hash) }

    context "when content is valid" do
      let!(:type) { "base-raid" }

      it "is expected to convert the content to a hash" do
        expect(notification.data).to eq(data)
      end
    end

    context "when content is invalid" do
      let!(:type) { "foobar" }

      it "is expected to raise NameError" do
        expect { notification }.to raise_error(
          NameError, "\"foobar\" is not a valid XM8 notification type"
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
end
