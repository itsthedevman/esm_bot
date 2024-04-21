# frozen_string_literal: true

module ESM
  class ExileTerritory < ArmaRecord
    class ArmaError < ESM::Exception::Error
    end

    FLAG_TEXTURES = %w[
      exile_assets\texture\flag\flag_mate_bis_co.paa exile_assets\texture\flag\flag_mate_vish_co.paa exile_assets\texture\flag\flag_mate_hollow_co.paa
      exile_assets\texture\flag\flag_mate_legion_ca.paa exile_assets\texture\flag\flag_mate_21dmd_co.paa exile_assets\texture\flag\flag_mate_spawny_co.paa
      exile_assets\texture\flag\flag_mate_secretone_co.paa exile_assets\texture\flag\flag_mate_stitchmoonz_co.paa
      exile_assets\texture\flag\flag_mate_commandermalc_co.paa \A3\Data_F\Flags\flag_blue_co.paa \A3\Data_F\Flags\flag_green_co.paa
      \A3\Data_F\Flags\flag_red_co.paa \A3\Data_F\Flags\flag_white_co.paa \A3\Data_F\Flags\flag_uk_co.paa exile_assets\texture\flag\flag_country_de_co.paa
      exile_assets\texture\flag\flag_country_at_co.paa exile_assets\texture\flag\flag_country_sct_co.paa exile_assets\texture\flag\flag_country_ee_co.paa
      exile_assets\texture\flag\flag_country_cz_co.paa exile_assets\texture\flag\flag_country_nl_co.paa exile_assets\texture\flag\flag_country_hr_co.paa
      exile_assets\texture\flag\flag_country_cn_co.paa exile_assets\texture\flag\flag_country_ru_co.paa exile_assets\texture\flag\flag_country_ir_co.paa
      exile_assets\texture\flag\flag_country_by_co.paa exile_assets\texture\flag\flag_country_fi_co.paa exile_assets\texture\flag\flag_country_fr_co.paa
      exile_assets\texture\flag\flag_country_au_co.paa exile_assets\texture\flag\flag_country_be_co.paa exile_assets\texture\flag\flag_country_se_co.paa
      exile_assets\texture\flag\flag_country_pl_co.paa exile_assets\texture\flag\flag_country_pl2_co.paa exile_assets\texture\flag\flag_country_pt_co.paa
      exile_assets\texture\flag\flag_mate_zanders_streched_co.paa exile_assets\texture\flag\flag_misc_brunswik_co.paa
      exile_assets\texture\flag\flag_misc_dorset_co.paa exile_assets\texture\flag\flag_misc_svarog_co.paa exile_assets\texture\flag\flag_misc_exile_co.paa
      exile_assets\texture\flag\flag_misc_utcity_co.paa exile_assets\texture\flag\flag_misc_dickbutt_co.paa exile_assets\texture\flag\flag_misc_rainbow_co.paa
      exile_assets\texture\flag\flag_misc_battleye_co.paa exile_assets\texture\flag\flag_misc_bss_co.paa exile_assets\texture\flag\flag_misc_skippy_co.paa
      exile_assets\texture\flag\flag_misc_kiwifern_co.paa exile_assets\texture\flag\flag_misc_trololol_co.paa exile_assets\texture\flag\flag_misc_dream_cat_co.paa
      exile_assets\texture\flag\flag_misc_pirate_co.paa exile_assets\texture\flag\flag_misc_pedobear_co.paa exile_assets\texture\flag\flag_misc_petoria_co.paa
      exile_assets\texture\flag\flag_misc_smashing_co.paa exile_assets\texture\flag\flag_misc_lemonparty_co.paa exile_assets\texture\flag\flag_misc_rma_co.paa
      exile_assets\texture\flag\flag_cp_co.paa exile_assets\texture\flag\flag_trouble2_co.paa exile_assets\texture\flag\flag_exile_city_co.paa
      exile_assets\texture\flag\flag_misc_eraser1_co.paa exile_assets\texture\flag\flag_misc_willbeeaten_co.paa
      exile_assets\texture\flag\flag_misc_privateproperty_co.paa exile_assets\texture\flag\flag_misc_nuclear_co.paa
      exile_assets\texture\flag\flag_misc_lazerkiwi_co.paa exile_assets\texture\flag\flag_misc_beardageddon_co.paa exile_assets\texture\flag\flag_country_dk_co.paa
      exile_assets\texture\flag\flag_country_it_co.paa exile_assets\texture\flag\flag_misc_alkohol_co.paa exile_assets\texture\flag\flag_misc_kickass_co.paa
      exile_assets\texture\flag\flag_misc_knuckles_co.paa exile_assets\texture\flag\flag_misc_snake_co.paa exile_assets\texture\flag\flag_misc_weeb_co.paa
    ].freeze

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
    attribute :flag_stolen, :boolean, default: false
    attribute :flag_stolen_by_uid, :string
    attribute :flag_stolen_at, :datetime
    attribute :created_at, :datetime, default: -> { Time.current }
    attribute :last_paid_at, :datetime, default: -> { Time.current }
    attribute :xm8_protectionmoney_notified, :boolean, default: false
    attribute :build_rights, :json
    attribute :moderators, :json
    attribute :esm_payment_counter, :integer, default: 0
    attribute :deleted_at, :datetime

    after_save :update_arma

    scope :active, -> { where(deleted_at: nil) }
    scope :not_stolen, -> { where(flag_stolen: false) }
    scope :owned_by, ->(user) { where(owner_uid: user.steam_uid) }
    scope :not_owned_by, ->(user) { where.not(owner_uid: user.steam_uid) }
    scope :built_by, ->(user) { where("build_rights LIKE ?", "%#{user.steam_uid}%") }
    scope :moderated_by, ->(user) { where("moderators LIKE ?", "%#{user.steam_uid}%") }
    scope :not_moderated_by, ->(user) { where.not("moderators LIKE ?", "%#{user.steam_uid}%") }

    scope :with_no_membership_for, ->(user) do
      where.not(owner_uid: user.steam_uid)
        .and(where.not("build_rights LIKE ?", "%#{user.steam_uid}%"))
        .and(where.not("moderators LIKE ?", "%#{user.steam_uid}%"))
    end

    def self.sampled_for(server)
      territory = all.sample
      territory.tap { |t| t.server_id = server.id }
    end

    def revoke_membership(steam_uid)
      self.owner_uid = ESM::Test.steam_uid if owner_uid == steam_uid
      moderators.delete(steam_uid)
      build_rights.delete(steam_uid)
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

    def create_flag
      sqf = <<~SQF
        private _flag = #{id} call ESMs_system_territory_get;
        if (!isNull _flag) exitWith { false };

        #{id} call ExileServer_system_territory_database_load;
      SQF

      result = server.execute_sqf!(sqf, steam_uid: owner_uid)
      success = result.data.result

      raise ArmaError, "Failed to create flag for territory id:#{id}" unless success
    end

    def delete_flag
      sqf = <<~SQF
        private _flag = #{id} call ESMs_system_territory_get;
        if (isNull _flag) exitWith { false };

        deleteVehicle _flag;
      SQF

      result = server.execute_sqf!(sqf, steam_uid: owner_uid)
      success = result.data.result

      raise ArmaError, "Failed to delete flag for territory id:#{id}" unless success
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
      return if changed_items.blank? || changed_items.key?("id")

      sqf = "private _flagObject = #{id} call ESMs_system_territory_get;"

      if ((_, new_value) = changed_items["owner_uid"])
        sqf += "_flagObject setVariable [\"ExileOwnerUID\", #{new_value.quoted}, true];"
      end

      if ((_, new_value) = changed_items["moderators"])
        sqf += "_flagObject setVariable [\"ExileTerritoryModerators\", #{new_value.to_json}, true];"
      end

      if ((_, new_value) = changed_items["build_rights"])
        sqf += "_flagObject setVariable [\"ExileTerritoryBuildRights\", #{new_value.to_json}, true];"
      end

      server.execute_sqf!(sqf, steam_uid: owner_uid)
    end
  end
end
