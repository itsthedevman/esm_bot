# frozen_string_literal: true

describe ESM::Service::Steam do
  let!(:steam) { ESM::Service::Steam.new(TestUser::User1::STEAM_UID) }

  it "should be valid" do
    expect(steam).not_to be_nil
  end

  it "should return 'Public'" do
    expect(steam.profile_visibility).to eq("Public")
  end
end
