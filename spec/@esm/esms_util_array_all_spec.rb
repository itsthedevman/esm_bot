# frozen_string_literal: true

describe "ESMs_util_array_all", requires_connection: true, v2: true do
  let!(:server) { ESM::Test.server }

  include_examples "connection"

  it "returns true" do
    response = execute_sqf!(
      <<~SQF
        private _result = [[1,2,3,4], { _this != 0 }] call ESMs_util_array_all;
        if (isNil "_result") exitWith { nil };

        _result
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq(true)
  end

  it "returns false" do
    response = execute_sqf!(
      <<~SQF
        private _result = [[1,2,3,4], { _this isEqualType "" }] call ESMs_util_array_all;
        if (isNil "_result") exitWith { nil };

        _result
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq(false)
  end

  it "returns false (mixed)" do
    response = execute_sqf!(
      <<~SQF
        private _result = [[1,2,3,4], { _this > 1 }] call ESMs_util_array_all;
        if (isNil "_result") exitWith { nil };

        _result
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq(false)
  end
end
