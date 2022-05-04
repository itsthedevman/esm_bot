# frozen_string_literal: true

describe "ESMs_util_hashmap_toArray", requires_connection: true, v2: true do
  include_examples "connection"

  it "converts the array to a hashmap" do
    response = execute_sqf!(
      <<~SQF
        private _footLongSubHashmap = ["key_6", "key_7"] createHashMapFromArray [6, nil];
        private _subHashmap = ["key_4", "key_5"] createHashMapFromArray [[4], _footLongSubHashmap];
        private _hashmap = ["key_1", "key_2", "key_3"] createHashMapFromArray ["value_1", true, _subHashmap];

        _result = _hashMap call ESMs_util_hashmap_toArray;
        if (isNil "_result") exitWith {};

        _result
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq('[["key_1","key_2","key_3"],["value_1",true,[["key_4","key_5"],[[4],[["key_6","key_7"],[6,any]]]]]]')
  end

  it "converts an array of hashmaps" do
    response = execute_sqf!(
      <<~SQF
        private _array = [];
        _array pushBack (["key_1", "key_2"] createHashMapFromArray ["value_1", "value_2"]);

        private _hashmap = ["1"] createHashMapFromArray ["11"];
        _array pushBack ([["sub_key_1", "sub_key_2"] createHashMapFromArray ["sub_value_1", [_hashmap]]]);

        _result = _array call ESMs_util_hashmap_toArray;
        if (isNil "_result") exitWith {};

        _result
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq(
      [
        # Normal Hashmap
        [["key_1", "key_2"], ["value_1", "value_2"]],

        # Another array containing hashmaps
        [
          [
            ["sub_key_2", "sub_key_1"],
            [
              # You guessed it, another array of hashmap
              [[["1"], ["11"]]],
              "sub_value_1"
            ]
          ]
        ]
      ]
    )
  end
end
