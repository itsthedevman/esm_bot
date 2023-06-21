# frozen_string_literal: true

module ESM
  class UserDefault < ApplicationRecord
    attribute :user_id, :integer
    attribute :community_id, :integer
    attribute :server_id, :integer

    belongs_to :user
    belongs_to :community
    belongs_to :server
  end
end
