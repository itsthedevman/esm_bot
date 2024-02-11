# frozen_string_literal: true

module ESM
  class Message
    class Data
      module Types
        RUBY_TYPE_LOOKUP = {
          Array => :array,
          Date => :date,
          DateTime => :date_time,
          ESM::Arma::HashMap => :hash_map,
          FalseClass => :boolean,
          Float => :float,
          Hash => :hash,
          ImmutableStruct => :struct,
          Integer => :integer,
          Numeric => :float,
          OpenStruct => :struct,
          String => :string,
          Struct => :struct,
          Symbol => :string,
          ::Time => :date_time,
          TrueClass => :boolean
        }.freeze

        TYPES = {
          any: {
            into_ruby: lambda do |value|
              # Check if it's JSON like
              result = ESM::JSON.parse(value.to_s)
              return value if result.nil?

              # Check to see if its a hashmap
              possible_hashmap = ESM::Arma::HashMap.from(result)
              return result if possible_hashmap.nil?

              result
            end,
            into_arma: ->(value) { value }
          },
          array: {
            valid_classes: [Array],
            into_ruby: ->(value) { value.to_a },
            into_arma: ->(value) { value.map { |v| convert_into_arma(v) } }
          },
          boolean: {
            valid_classes: [TrueClass, FalseClass],
            into_ruby: ->(value) { value.to_s == "true" }
          },
          date: {
            valid_classes: [Date],
            into_ruby: ->(value) { ::Date.parse(value) },
            into_arma: ->(value) { value.strftime("%F") }
          },
          date_time: {
            valid_classes: [DateTime, ::Time],
            into_ruby: ->(value) { ESM::Time.parse(value) },
            into_arma: ->(value) { value.strftime("%FT%T%:z") } # yyyy-mm-ddT00:00:00ZONE
          },
          float: {
            valid_classes: [Float],
            into_ruby: ->(value) { value.to_d },
            into_arma: ->(value) { value.to_s }  # Numbers have to be sent as Strings
          },
          hash: {
            valid_classes: [Hash],
            into_ruby: ->(value) { value.to_h },
            into_arma: ->(value) { value.transform_values { |v| convert_into_arma(v) } }
          },
          hash_map: {
            valid_classes: [ESM::Arma::HashMap],
            into_ruby: ->(value) { ESM::Arma::HashMap.from(value) },
            into_arma: ->(value) { value.to_h.transform_values { |v| convert_into_arma(v) } }
          },
          integer: {
            valid_classes: [Integer],
            into_ruby: ->(value) { value.to_i },
            into_arma: ->(value) { value.to_s } # Numbers have to be sent as Strings
          },
          string: {
            valid_classes: [String],
            into_ruby: ->(value) { value.to_s },
            into_arma: ->(value) { value.to_s } # Symbol uses this as well
          },
          struct: {
            valid_classes: [ImmutableStruct, Struct, OpenStruct],
            into_ruby: ->(value) { value.to_h.to_istruct },
            into_arma: ->(value) { value.to_h.transform_values { |v| convert_into_arma(v) } }
          }
        }.freeze

        TYPES_MAPPING = {
          empty: {},
          handshake: {
            indices: {
              type: :array,
              subtype: :integer
            }
          },
          init: {
            extension_version: :string,
            price_per_object: :integer,
            server_name: :string,
            server_start_time: :date_time,
            territory_data: {
              type: :array,
              subtype: :hash_map
            },
            territory_lifetime: :integer,
            vg_enabled: :boolean,
            vg_max_sizes: {
              type: :array,
              subtype: :integer
            }
          },
          post_init: {
            community_id: :string,
            extdb_path: :string,
            gambling_modifier: :integer,
            gambling_payout_base: :integer,
            gambling_payout_randomizer_max: :float,
            gambling_payout_randomizer_mid: :float,
            gambling_payout_randomizer_min: :float,
            gambling_win_percentage: :integer,
            logging_add_player_to_territory: :boolean,
            logging_channel_id: :string,
            logging_demote_player: :boolean,
            logging_exec: :boolean,
            logging_gamble: :boolean,
            logging_modify_player: :boolean,
            logging_pay_territory: :boolean,
            logging_promote_player: :boolean,
            logging_remove_player_from_territory: :boolean,
            logging_reward_player: :boolean,
            logging_transfer_poptabs: :boolean,
            logging_upgrade_territory: :boolean,
            max_payment_count: :integer,
            server_id: :string,
            territory_admin_uids: {
              type: :array,
              subtype: :string
            },
            taxes_territory_payment: :integer,
            taxes_territory_upgrade: :integer
          },
          query: {
            arguments: :hash,
            name: :string
          },
          query_result: {
            results: {
              type: :array,
              subtype: :hash
            }
          },
          reward: {
            items: {
              type: :hash_map,
              optional: true
            },
            locker_poptabs: {
              type: :integer,
              optional: true
            },
            player_poptabs: {
              type: :integer,
              optional: true
            },
            respect: {
              type: :integer,
              optional: true
            },
            vehicles: {
              type: :array,
              subtype: :hash_map,
              optional: true
            }
          },
          send_to_channel: {
            id: :string,
            content: :string
          },
          sqf: {
            execute_on: :string,
            code: :string
          },
          sqf_result: {
            result: :any
          },
          add: {
            territory: :hash
          }
        }.freeze
      end
    end
  end
end
