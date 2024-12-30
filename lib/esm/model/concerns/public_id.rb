# frozen_string_literal: true

module ESM
  module Concerns
    module PublicId
      extend ActiveSupport::Concern

      included do
        attribute :public_id, :string

        before_create :generate_public_id
      end

      private

      def generate_public_id
        return if public_id.present?

        self.public_id = SecureRandom.uuid
      end
    end
  end
end
