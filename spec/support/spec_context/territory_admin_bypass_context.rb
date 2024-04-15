# frozen_string_literal: true

RSpec.shared_context("territory_admin_bypass") do
  before do
    before_connection do
      community.update!(territory_admin_ids: [community.everyone_role_id])
    end
  end

  after do
    ESM::Test.callbacks.remove_all_callbacks!
  end
end
