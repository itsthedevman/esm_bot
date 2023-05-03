# frozen_string_literal: true

describe "ESMs_system_territory_checkAccess", requires_connection: true, v2: true do
  include_context "connection"

  let!(:territory) do
    ESM::ExileTerritory.all
      .active
      .moderated_by(user)
      .sampled_for(server)
  end

  it "returns true because the Player has correct permissions" do
    response = execute_sqf!(
      <<~SQF
        private _territory = #{territory.id} call ESMs_system_territory_get;
        [#{user.steam_uid.quoted}, _territory, "moderator"] call ESMs_system_territory_checkAccess
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq(true)
  end

  describe "Territory Admin" do
    before :context do
      before_connection do
        community.update!(territory_admin_ids: [community.everyone_role_id])
      end
    end

    it "returns true because the Player is a Territory Admin" do
      territory = ESM::ExileTerritory.all.active.with_no_membership_for(user).sampled_for(server)

      response = execute_sqf!(
        <<~SQF
          private _territory = #{territory.id} call ESMs_system_territory_get;
          [#{user.steam_uid.quoted}, _territory, "moderator"] call ESMs_system_territory_checkAccess
        SQF
      )

      expect(response).not_to be_nil
      expect(response.data.result).to eq(true)
    end
  end

  it "returns false because the Player is missing rights" do
    territory.revoke_membership(user)
    
    response = execute_sqf!(
      <<~SQF
        private _territory = #{territory.id} call ESMs_system_territory_get;
        [#{user.steam_uid.quoted}, _territory, "moderator"] call ESMs_system_territory_checkAccess
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq(false)
  end

  it "returns false because the Player has lower than required permissions" do
    response = execute_sqf!(
      <<~SQF
        private _territory = #{territory.id} call ESMs_system_territory_get;
        [#{user.steam_uid.quoted}, _territory, "owner"] call ESMs_system_territory_checkAccess
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq(false)
  end
end
