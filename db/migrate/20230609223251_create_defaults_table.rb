# frozen_string_literal: true

class CreateDefaultsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :community_defaults, if_not_exists: true do |t|
      t.belongs_to :community, foreign_key: true
      t.references :server, index: true, foreign_key: true
      t.string :channel_id, null: true

      t.index [:community_id, :channel_id]
    end

    create_table :user_defaults, if_not_exists: true do |t|
      t.belongs_to :user, index: true, foreign_key: true
      t.references :community, index: true, foreign_key: true, null: true
      t.references :server, index: true, foreign_key: true, null: true
    end

    create_table :user_aliases, if_not_exists: true do |t|
      t.belongs_to :user, foreign_key: true
      t.references :community, index: true, foreign_key: true, null: true
      t.references :server, index: true, foreign_key: true, null: true
      t.string :value, null: false

      t.index [:user_id, :community_id, :value], unique: true
      t.index [:user_id, :server_id, :value], unique: true
    end
  end
end
