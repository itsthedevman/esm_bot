# frozen_string_literal: true

describe ESM::Command::Server::Sqf, category: "command" do
  include_examples "command", described_class

  it "is an admin command" do
    expect(command.type).to eql(:admin)
  end

  it "requires registration" do
    expect(command.registration_required?).to be(true)
  end

  # Change "requires_connection" to true if this command requires the client to be connected
  describe "#on_execute/#on_response", requires_connection: true do
    include_context "connection"

    before :each do
      grant_command_access!(community, "sqf")
    end

    it "executes (On server/with reply)" do
      execute!(server_id: server.server_id, code_to_execute: "_test = true;\n_test")
      wait_for { ESM::Test.messages }.not_to be_empty

      message = ESM::Test.messages.first
      expect(message).not_to be_nil

      result_embed = message.content
      expect(result_embed.description).to eq(command.t("responses.server_with_result", server_id: server.server_id, result: "true", result_type: "BOOL", user: user.mention))
    end

    it "executes (On server/no reply)" do
      execute!(server_id: server.server_id, code_to_execute: "if (false) then { \"true\" };")
    end

    it "executes (On target/no reply)" do
      execute!(server_id: server.server_id, target: user.mention, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")
    end

    it "executes (On target/with reply)" do
      execute!(server_id: server.server_id, target: user.mention, code_to_execute: "player setVariable [\"This code\", \"does not matter\"]; ")
    end

    it "executes (On non-registered steam uid)" do
      execute!(server_id: server.server_id, target: steam_uid, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")
    end

    it "raises (Target is not online)" do
      execute!(server_id: server.server_id, target: user.mention, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")
    end

    it "raises (Target is not registered)" do
      execute!(server_id: server.server_id, target: second_user.mention, code_to_execute: "player setVariable [\"This code\", \"does not matter\"];")
    end

    it "minifies the code"
  end
end
