# frozen_string_literal: true

module ESM
  class ExileTerritory < ArmaRecord
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

    after_save :update_arma

    scope :active, -> { where(deleted_at: nil) }
    scope :not_stolen, -> { where(flag_stolen: false) }
    scope :owned_by, ->(user) { where(owner_uid: user.steam_uid) }
    scope :built_by, ->(user) { where("build_rights LIKE ?", "%#{user.steam_uid}%") }
    scope :moderated_by, ->(user) { where("moderators LIKE ?", "%#{user.steam_uid}%") }

    scope :with_no_membership_for, ->(user) do
      where.not(owner_uid: user.steam_uid)
        .and(where.not("build_rights LIKE ?", "%#{user.steam_uid}%"))
        .and(where.not("moderators LIKE ?", "%#{user.steam_uid}%"))
    end

    def self.sampled_for(server)
      territory = all.sample
      territory.tap { |t| t.server_id = server.id }
    end

    def revoke_membership(user)
      moderators.delete(user.steam_uid)
      build_rights.delete(user.steam_uid)
      save! if changed?
      self
    end

    def server
      ESM::Server.find(server_id)
    end

    def encoded_id
      @encoded_id ||= begin
        hashids = Hashids.new(server.server_key, 5, "abcdefghijklmnopqrstuvwxyz")
        hashids.encode(id)
      end
    end

    def delete_flag
      sqf = "private _flagObject = #{id} call ESMs_object_flag_get; deleteVehicle _flagObject;"
      ESM::Test.execute_sqf!(server.connection, sqf, steam_uid: owner_uid)
    end

    private

    # _flagObject setVariable ["ExileTerritoryName", _name, true];
    # _flagObject setVariable ["ExileDatabaseID", _id];
    # _flagObject setVariable ["ExileOwnerUID", _owner, true];
    # _flagObject setVariable ["ExileTerritorySize", _radius, true];
    # _flagObject setVariable ["ExileTerritoryLevel", _level, true];
    # _flagObject setVariable ["ExileTerritoryLastPayed", _lastPayed];
    # _flagObject call ExileServer_system_territory_maintenance_recalculateDueDate;
    # _flagObject setVariable ["ExileTerritoryNumberOfConstructions", _data select 15, true];
    # _flagObject setVariable ["ExileRadiusShown", false, true];
    # _flagObject setVariable ["ExileFlagStolen",_flagStolen,true];
    # _flagObject setVariable ["ExileFlagTexture",_flagTexture];
    def update_arma
      changed_items = previous_changes.except("server_id")
      return if changed_items.blank?

      sqf = "private _flagObject = #{id} call ESMs_object_flag_get;"
      if ((_, new_value) = changed_items["moderators"])
        sqf += "_flagObject setVariable [\"ExileTerritoryModerators\", #{new_value}, true];"
      end

      if ((_, new_value) = changed_items["build_rights"])
        sqf += "_flagObject setVariable [\"ExileTerritoryBuildRights\", #{new_value}, true];"
      end

      ESM::Test.execute_sqf!(server.connection, sqf, steam_uid: owner_uid)
    end
  end
end
