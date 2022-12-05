# frozen_string_literal: true

describe Discordrb::User do
  describe "#steam_uid" do
    it "should respond" do
      user = ESM.bot.user(TestUser::User1::ID)
      expect(user.respond_to?(:steam_uid)).to be(true)
    end

    it "should get and set" do
      user = ESM.bot.user(TestUser::User1::ID)
      user.steam_uid = TestUser::User1::STEAM_UID
      expect(user.steam_uid).to eq(TestUser::User1::STEAM_UID)
    end
  end

  describe "#esm_user" do
    it "should respond" do
      user = ESM.bot.user(TestUser::User1::ID)
      expect(user.respond_to?(:esm_user)).to be(true)
    end

    it "should get and set" do
      user = ESM.bot.user(TestUser::User1::ID)
      db_user = create(:esm_dev)
      user.instance_variable_set(:@esm_user, db_user)
      expect(user.esm_user.id).to eq(db_user.id)
    end
  end
end
