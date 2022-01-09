# frozen_string_literal: true

describe "ESMs_util_hashmap_toArray", requires_connection: true, v2: true do
  let!(:server) { ESM::Test.server }

  include_examples "connection"

  it "converts the array to a hashmap" do
    response = execute_sqf!(
      <<~SQF
        private _hashMap = [
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
        ] call ESMs_util_hashmap_fromArray;

        _result = _hashMap call ESMs_util_hashmap_toArray;
        if (isNil "_result") exitWith {};

        _result
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq('[["key_1","key_2","key_3"],["value_1",true,[["key_4","key_5"],[false,[["key_6","key_7"],[6,any]]]]]]')
  end
end
