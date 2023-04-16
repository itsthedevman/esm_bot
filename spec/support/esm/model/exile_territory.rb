# frozen_string_literal: true

class ExileTerritory < MysqlRecord
  self.table_name = "territory"

  attribute :id, :integer
  attribute :server_id, :integer # Not a database field in mysql
  attribute :esm_custom_id, :string
  attribute :owner_uid, :string
  attribute :name, :string
  attribute :position_x, :float
  attribute :position_y, :float
  attribute :position_z, :float
  attribute :radius, :float
  attribute :level, :integer
  attribute :flag_texture, :string
  attribute :flag_stolen, :boolean
  attribute :flag_stolen_by_uid, :string
  attribute :flag_stolen_at, :datetime
  attribute :created_at, :datetime
  attribute :last_paid_at, :datetime
  attribute :xm8_protectionmoney_notified, :boolean
  attribute :build_rights, :json
  attribute :moderators, :json
  attribute :esm_payment_counter, :integer
  attribute :deleted_at, :datetime

  def server
    ESM::Server.find(server_id)
  end

  def encoded_id
    @encoded_id ||= begin
      hashids = Hashids.new(server.server_key, 5, "abcdefghijklmnopqrstuvwxyz")
      hashids.encode(id)
    end
  end
end
