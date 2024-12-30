class ServerRewards < ActiveRecord::Migration[7.2]
  def change
    rebuild_rewards_table
    create_reward_items_table
  end

  private

  def rebuild_rewards_table
    remove_index :server_rewards, :deleted_at, if_exists: true
    remove_index :server_rewards, [:server_id, :reward_id], if_exists: true
    remove_index :server_rewards, :server_id, if_exists: true

    remove_foreign_key :server_rewards, :servers, if_exists: true

    create_table :server_rewards_new do |t|
      t.uuid :public_id, null: false # new
      t.belongs_to :server, foreign_key: {on_delete: :cascade}
      t.string :reward_id

      t.integer :cooldown_quantity, default: 2 # new
      t.string :cooldown_type, default: "never" # new

      # Deprecated - To be removed later
      t.json :reward_items, default: {}
      t.bigint :player_poptabs, default: 0
      t.bigint :locker_poptabs, default: 0
      t.bigint :respect, default: 0
      ##

      t.timestamps # new

      t.index :public_id, unique: true
      t.index [:server_id, :reward_id], unique: true
    end

    ESM::ServerReward.all.includes(:server).each do |entry|
      connection.execute(
        ESM::Database::Helpers.generate_insert_from_hash(
          :server_rewards_new,
          public_id: SecureRandom.uuid,
          server_id: entry[:server_id],
          reward_id: entry[:reward_id],
          reward_items: entry[:reward_items].to_json,
          player_poptabs: entry[:player_poptabs],
          locker_poptabs: entry[:locker_poptabs],
          respect: entry[:respect],
          created_at: entry.server.created_at,
          updated_at: Time.current
        )
      )
    end

    drop_table(:server_rewards)
    rename_table(:server_rewards_new, :server_rewards)
  end

  def create_reward_items_table
    create_table :server_reward_items, if_not_exists: true do |t|
      t.uuid :public_id, null: false
      t.belongs_to :server_reward, foreign_key: {on_delete: :cascade}
      t.string :reward_type, null: false
      t.string :classname
      t.integer :amount, null: false
      t.integer :expiry_value, null: false, default: 0
      t.string :expiry_unit, null: false, default: "never"
      t.timestamps

      t.index :public_id, unique: true
      t.index :server_reward_id
    end
  end
end
