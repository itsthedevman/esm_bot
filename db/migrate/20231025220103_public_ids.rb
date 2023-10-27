# frozen_string_literal: true

class PublicIds < ActiveRecord::Migration[6.1]
  def change
    rename_column :servers, :uuid, :public_id

    remove_foreign_key "command_configurations", "communities"
    remove_foreign_key "community_defaults", "communities"
    remove_foreign_key "cooldowns", "communities"
    remove_foreign_key "servers", "communities"
    remove_foreign_key "user_aliases", "communities"
    remove_foreign_key "user_defaults", "communities"
    remove_foreign_key "user_notification_routes", "communities", column: "destination_community_id"

    rename_table(:communities, :communities_old)

    create_table "communities" do |t|
      t.uuid "public_id", null: false
      t.string "community_id", null: false
      t.text "community_name"
      t.string "guild_id", null: false
      t.string "logging_channel_id"
      t.boolean "log_reconnect_event", default: false
      t.boolean "log_xm8_event", default: true
      t.boolean "log_discord_log_event", default: true
      t.boolean "player_mode_enabled", default: true
      t.json "territory_admin_ids", default: []
      t.json "dashboard_access_role_ids", default: []
      t.string "command_prefix"
      t.boolean "welcome_message_enabled", default: true
      t.text "welcome_message", default: ""
      t.timestamps

      t.index ["public_id"], unique: true
      t.index ["community_id"], unique: true
      t.index ["guild_id"], unique: true
    end

    # Migrate the old data over to the new table
    ESM::Community.reset_column_information
    data = query("SELECT * FROM communities_old;")
    communities = data.map do |community|
      community["public_id"] = SecureRandom.uuid
      community.except("deleted_at")
    end

    ESM::Community.insert_all(communities) if communities.size > 0

    # Delete old table
    drop_table(:communities_old)

    add_foreign_key "command_configurations", "communities", on_delete: :cascade
    add_foreign_key "community_defaults", "communities", on_delete: :cascade
    add_foreign_key "cooldowns", "communities", on_delete: :cascade
    add_foreign_key "servers", "communities", on_delete: :cascade
    add_foreign_key "user_aliases", "communities", on_delete: :cascade
    add_foreign_key "user_defaults", "communities", on_delete: :cascade
    add_foreign_key "user_notification_routes", "communities", column: "destination_community_id", on_delete: :cascade
  end
end
