class UserNotificationRoutes < ActiveRecord::Migration[6.1]
  def change
    create_table :user_notification_routes do |t|
      t.uuid :uuid, index: true
      t.integer :user_id
      t.integer :community_id
      t.integer :server_id, null: true
      t.string :channel_id
      t.string :notification_type
      t.boolean :user_accepted, default: false
      t.boolean :community_accepted, default: false
      t.timestamps
    end

    add_foreign_key :user_notification_routes, :users
    add_foreign_key :user_notification_routes, :servers
    add_foreign_key :user_notification_routes, :communities
  end
end
