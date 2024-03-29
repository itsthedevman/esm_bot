# frozen_string_literal: true

describe ESM::Websocket::Request do
  let(:user) { ESM::Test.user }

  it "accepts string for command name" do
    request = ESM::Websocket::Request.new(
      command_name: "testing",
      user: nil,
      parameters: nil,
      channel: nil
    )

    expect(request).not_to be_nil
    expect(request.command_name).to eq("testing")
  end

  it "accepts ESM::Command for command" do
    request = ESM::Websocket::Request.new(
      command: ESM::Command::Test::BaseV1.new,
      user: nil,
      parameters: nil,
      channel: nil
    )

    expect(request).not_to be_nil
    expect(request.command_name).to eq("base_v1")
  end

  it "accepts nil for user" do
    request = ESM::Websocket::Request.new(
      command_name: "testing",
      user: nil,
      parameters: nil,
      channel: nil
    )

    expect(request).not_to be_nil
    expect(request.user).to be_nil
    expect(request.user_info).to eq(["", ""])
  end

  it "accepts a valid user" do
    discord_user = user.discord_user
    request = ESM::Websocket::Request.new(
      command_name: "testing",
      user: discord_user,
      parameters: nil,
      channel: nil
    )

    expect(request).not_to be_nil
    expect(request.user).not_to be_nil
    expect(request.user_info).to eq([discord_user.mention, discord_user.id])
  end

  describe "#to_s" do
    it "is valid" do
      params = {
        foo: "Foo",
        bar: ["Bar"],
        baz: false
      }

      request = create_request(**params)
      user = request.user

      valid_hash_string = {
        "command" => "base_v1",
        "commandID" => request.id,
        "authorInfo" => [user.mention, user.id],
        "parameters" => params
      }.to_json

      expect(request.to_s).to eq(valid_hash_string)
    end
  end

  describe "#timed_out?" do
    it "timed out" do
      request = ESM::Websocket::Request.new(command_name: "testing", user: nil, channel: nil, command: nil, parameters: nil, timeout: 0)
      expect(request.timed_out?).to be(true)
    end

    it "didn't time out" do
      request = ESM::Websocket::Request.new(command_name: "testing", user: nil, channel: nil, command: nil, parameters: nil)
      expect(request.timed_out?).to be(false)
    end
  end
end
