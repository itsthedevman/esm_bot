# frozen_string_literal: true

describe "ESMs_util_hashmap_fromArray", requires_connection: true do
  let!(:server) { ESM::Test.server }

  include_examples "connection"

  it "converts the array to a hashmap" do
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
        ] call ESMs_util_hashmap_fromArray;

        if (isNil "_result") exitWith {};
        if !(_result isEqualType createHashMap) exitWith {};

        _result
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq('[["key_1","value_1"],["key_2",true],["key_3",[["key_4",false],["key_5",[["key_6",6],["key_7",any]]]]]]')
  end
end
