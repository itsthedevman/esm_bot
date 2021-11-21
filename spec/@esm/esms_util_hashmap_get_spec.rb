# frozen_string_literal: true

describe "ESMs_util_hashmap_get", requires_connection: true do
  let!(:server) { ESM::Test.server }

  include_examples "connection"

  (1..5).each do |level|
    it "extracts the value from the hashmap (#{level} levels deep)" do
      keys = Array.new(level) { SecureRandom.uuid }
      expected_value = SecureRandom.uuid
      expected_key = keys.delete_at(level - 1)

      # _hash3 set ["key_3", "value"];
      # _hash2 set ["key_2", _hash3];
      # _hash1 set ["key_1", _hash2];
      # [_hash1, "key_1", "key_2", "key_3"] call ESMs_util_hashmap_get;"
      sqf = ""
      (1..level).each do |index|
        sqf += "private _hash#{index} = createHashMap;"
      end

      sqf += "_hash#{level} set [\"#{expected_key}\", \"#{expected_value}\"];"

      keys.reverse.each_with_index do |key, index|
        sqf += "_hash#{level - (index + 1)} set [\"#{key}\", _hash#{level - index}];"
      end

      sqf += "[_hash1,"
      sqf += keys.format { |key| "\"#{key}\"," }
      sqf += "\"#{expected_key}\"] call ESMs_util_hashmap_get"

      response = execute_sqf!(sqf)
      expect(response).not_to be_nil
      expect(response.data.result).to eq(expected_value)
    end
  end
end
