# frozen_string_literal: true

module ESM
  class UserAlias < ApplicationRecord
    attribute :user_id, :integer
    attribute :community_id, :integer
    attribute :server_id, :integer
    attribute :value, :string

    belongs_to :user
    belongs_to :community
    belongs_to :server

    validates :value, uniqueness: {scope: [:user_id, :server_id]}
    validates :value, uniqueness: {scope: [:user_id, :community_id]}

    def self.find_server_alias(value)
      where(value: value).where.not(server_id: nil).first
    end

    def self.find_community_alias(value)
      where(value: value).where.not(community_id: nil).first
    end
  end
end
