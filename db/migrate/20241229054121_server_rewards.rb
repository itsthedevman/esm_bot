class ServerRewards < ActiveRecord::Migration[7.2]
  def change
    create_table :server_reward_items, if_not_exists: true do |t|
      t.uuid :public_id, null: false
      t.belongs_to :server_reward, foreign_key: true
      t.string :reward_type, null: false
      t.string :classname
      t.integer :amount, null: false
      t.integer :expiry_value, null: false, default: 0
      t.string :expiry_unit, null: false, default: "never"
      t.timestamps null: false

      t.index :public_id, unique: true
    end
  end
end
