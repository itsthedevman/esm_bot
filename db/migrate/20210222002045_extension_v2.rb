# frozen_string_literal: true

class ExtensionV2 < ActiveRecord::Migration[6.0]
  def change
    add_column(:servers, :server_version, :string)
    add_column(:server_rewards, :reward_id, :string)
    add_column(:server_rewards, :reward_vehicles, :json)
    add_column(:server_rewards, :cooldown_quantity, :integer)
    add_column(:server_rewards, :cooldown_type, :string)

    add_index(:server_rewards, [:server_id, :reward_id], unique: true)
  end
end
