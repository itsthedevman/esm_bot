class AddLoggingRewardAdmin < ActiveRecord::Migration[7.2]
  def change
    add_column(:server_settings, :logging_reward_admin, :boolean, default: true, if_not_exists: true)
  end
end
