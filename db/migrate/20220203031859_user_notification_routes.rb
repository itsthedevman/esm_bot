class UserNotificationRoutes < ActiveRecord::Migration[6.1]
  def change
    create_table :user_notification_routes do |t|
      t.integer :user_id
      t.integer :community_id
      t.integer :server_id
      t.string :notification_type
      t.boolean :enabled, default: true
      t.timestamps
    end

    add_foreign_key :user_notification_routes, :users
    add_foreign_key :user_notification_routes, :servers
    add_foreign_key :user_notification_routes, :communities
  end
end
