class CooldownTypes < ActiveRecord::Migration[7.2]
  def change
    rebuild_cooldowns_table
  end

  private

  def rebuild_cooldowns_table
    remove_index :cooldowns, %i[command_name user_id community_id]
    remove_index :cooldowns, %i[command_name steam_uid community_id]

    create_table :cooldowns_new do |t|
      t.uuid :public_id, null: false # new

      t.belongs_to :community, foreign_key: {on_delete: :cascade}
      t.belongs_to :server, null: true, foreign_key: {on_delete: :cascade}
      t.belongs_to :user, null: true, foreign_key: {on_delete: :cascade}
      t.string :steam_uid

      # Replaces command_name
      t.string :type, null: false # new
      t.string :key, null: false # new

      t.integer :cooldown_quantity, null: false, default: 2
      t.string :cooldown_type, null: false, default: "seconds"

      t.integer :cooldown_amount, default: 0
      t.datetime :expires_at

      t.timestamps

      t.index :public_id, unique: true
      t.index %i[community_id user_id type key], unique: true
      t.index %i[community_id steam_uid type key], unique: true
    end

    ESM::Cooldown.all.each do |entry|
      connection.execute(
        ESM::Database::Helpers.generate_insert_from_hash(
          :cooldowns_new,
          public_id: SecureRandom.uuid,
          type: :command,
          key: entry[:command_name],
          **entry.slice(
            :community_id, :server_id, :user_id, :steam_uid,
            :cooldown_quantity, :cooldown_type, :cooldown_amount,
            :expires_at, :created_at, :updated_at
          )
        )
      )
    end

    drop_table(:cooldowns)
    rename_table(:cooldowns_new, :cooldowns)
  end
end
