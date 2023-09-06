# frozen_string_literal: true

describe ESM::Command::Server::Server, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    it "returns invalid server" do
      expect { execute!(server_id: "esm_test") }.to raise_error(ESM::Exception::CheckFailure)
    end

    it "returns an embed" do
      expect { execute!(server_id: server.server_id) }.not_to raise_error
      response = ESM::Test.messages.first.second

      # Reload because the server updates when the WSC connects
      server.reload
      expect(response).not_to be_nil
      expect(response.title).to eq(server.server_name)
      expect(response.description).to be_nil
      expect(response.fields).not_to be_empty
      expect(response.fields.first.name).to eq("Server ID")
      expect(response.fields.first.value).to eq("```#{server.server_id}```")
      expect(response.fields.second.name).to eq("IP")
      expect(response.fields.second.value).to eq("```#{server.server_ip}```")
      expect(response.fields.third.name).to eq("Port")
      expect(response.fields.third.value).to eq("```#{server.server_port}```")
      expect(response.fields.fourth.name).to eq("✅ Online for")
      expect(response.fields.fifth.name).to eq("⏰ Next restart in")
    end

    it "works on an offline server" do
      wsc.disconnect!
      expect { execute!(server_id: server.server_id) }.not_to raise_error
    end
  end
end
