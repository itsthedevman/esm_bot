# frozen_string_literal: true

describe "ESMs_util_array_isValidHashmap", :requires_connection, v2: true do
  include_context "connection"

  context "when the array is not a valid hash map" do
    it "returns false" do
      response = execute_sqf!(
        <<~SQF
          private _result = [
            ["key_1", "key_2", "key_3"],
            [
              "value_1",
              true,
              [
                ["key_4", "key_5"],
                [
                  false,
                  [
                    ["key_6", "key_7"],
                    [6, nil]
                  ]
                ]
              ]
            ]
          ] call ESMs_util_array_isValidHashmap;

          _result
        SQF
      )

      expect(response).to be(false)
    end
  end

  context "when the array is a valid hash map" do
    it "returns true" do
      response = execute_sqf!(
        <<~SQF
          private _result = [
            ["key_1", "value_1"],
            ["key_2", true],
            [
              "key_3",
              [
                ["key_4", false],
                [
                  "key_5",
                  [
                    ["key_6", 6],
                    ["key_7", nil]
                  ]
                ]
              ]
            ]
          ] call ESMs_util_array_isValidHashmap;

          _result
        SQF
      )

      expect(response).to be(true)
    end
  end
end
