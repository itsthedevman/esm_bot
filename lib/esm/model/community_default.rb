# frozen_string_literal: true

module ESM
  class CommunityDefault < ApplicationRecord
    attribute :community_id, :integer
    attribute :server_id, :integer
    attribute :channel_id, :string

    belongs_to :community
    belongs_to :server
  end
end
