# frozen_string_literal: true

describe ESM::Command::Base::Checks do
  let!(:command) { ESM::Command::Test::TargetCommand.new }
  let!(:community) { ESM::Test.community }
  let!(:user) { ESM::Test.user }
  let!(:second_user) { ESM::Test.user }

  before :each do
    command.instance_variable_set(:@current_user, user.discord_user)
  end

  describe "#registered_target_user!" do
    it "should not raise (target_user is nil)" do
      command.instance_variable_set(:@target_user, nil)
      expect { command.check_registered_target_user! }.not_to raise_error
    end

    it "should not raise (target_user is registered)" do
      command.instance_variable_set(:@target_user, user.discord_user)
      expect { command.check_registered_target_user! }.not_to raise_error
    end

    it "should raise (target_user is of type User::Ephemeral)" do
      steam_uid = second_user.steam_uid
      second_user.destroy

      command.instance_variable_set(:@target_user, ESM::User::Ephemeral.new(steam_uid))
      expect { command.check_registered_target_user! }.to raise_error(ESM::Exception::CheckFailure, /has not registered with me yet/i)
    end

    it "should raise (target_user is not registered)" do
      second_user.update!(steam_uid: "")

      command.instance_variable_set(:@target_user, second_user)
      expect { command.check_registered_target_user! }.to raise_error(ESM::Exception::CheckFailure, /has not registered with me yet/i)
    end
  end
end
