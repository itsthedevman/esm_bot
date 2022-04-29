# frozen_string_literal: true

describe "ESMs_object_embed_create", requires_connection: true, v2: true do
  let!(:server) { ESM::Test.server }

  include_examples "connection"

  it "returns the embed" do
    response = execute_sqf!(
      <<~SQF
        [["title", "description"], ["This is the title", "This is a description"]] call ESMs_object_embed_create
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq([["description", "This is a description"], ["title", "This is the title"]])
  end

  it "skips invalid keys" do
    response = execute_sqf!(
      <<~SQF
        [["title", "descrition"], ["This is the title", "This is a description"]] call ESMs_object_embed_create
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq([["title", "This is the title"]])
  end

  it "skips invalid values" do
    response = execute_sqf!(
      <<~SQF
        [["title", "description"], [nil, "This is a description"]] call ESMs_object_embed_create
      SQF
    )

    expect(response).not_to be_nil
    expect(response.data.result).to eq([["description", "This is a description"]])
  end
end
