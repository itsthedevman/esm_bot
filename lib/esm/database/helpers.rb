# frozen_string_literal: true

module ESM
  class Database
    class Helpers
      def self.generate_insert_from_hash(table_name, **column_values)
        columns = column_values.keys.join(", ")
        placeholders = Array.new(column_values.size, "?").join(", ")

        sql = "INSERT INTO #{table_name} (#{columns}) VALUES (#{placeholders})"
        ESM::ApplicationRecord.sanitize_sql_array([sql, *column_values.values])
      end
    end
  end
end
