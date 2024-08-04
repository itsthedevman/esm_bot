# frozen_string_literal: true

describe ESM::Command::Server::Gamble, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      context "when the amount is a number" do
        it "gambles with the amount of poptabs on the server" do
          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "300"})

          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).not_to be_blank
          expect(embed.description).not_to be_blank
        end
      end

      context "when the amount is 'half'" do
        it "gambles half of the user's poptabs on the server" do
          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "half"})

          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).not_to be_blank
          expect(embed.description).not_to be_blank
        end
      end

      context "when the amount is 'all'" do
        it "gambles all of the players money" do
          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "all"})
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).not_to be_blank
          expect(embed.description).not_to be_blank
        end
      end

      context "when the user does not have enough poptabs" do
        it "returns an error from the server" do
          wsc.flags.NOT_ENOUGH_MONEY = true

          request = execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "100000000"})
          expect(request).not_to be_nil
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          expect(embed.description).to match(/not enough poptabs/i)
        end
      end

      context "when the amount is 0" do
        it "raises an exception" do
          execution_args = {channel_type: :dm, arguments: {server_id: server.server_id, amount: "0"}}

          expect { execute!(**execution_args) }.to raise_error(
            ESM::Exception::CheckFailure,
            /you simply cannot gamble nothing/
          )
        end
      end

      context "when the amount is negative" do
        it "raises an exception" do
          execution_args = {channel_type: :dm, arguments: {server_id: server.server_id, amount: "-1"}}

          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure)
        end
      end

      context "when the amount is 'stats'" do
        it "returns the gambling stats for the server" do
          execute!(channel_type: :dm, arguments: {server_id: server.server_id, amount: "stats"})

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).to match("Gambling statistics")
          expect(embed.fields.size).to eq(14)
        end
      end

      context "when the amount is omitted" do
        it "returns the gambling stats for the server" do
          execute!(channel_type: :dm, arguments: {server_id: server.server_id})

          embed = ESM::Test.messages.first.content
          expect(embed).not_to be(nil)
          expect(embed.title).to match("Gambling statistics")
          expect(embed.fields.size).to eq(14)
        end
      end
    end
  end

  describe "V2", v2: true do
    it "is a player command" do
      expect(command.type).to eq(:player)
    end

    describe "#on_execute", requires_connection: true do
      include_context "connection"

      context "when the amount is omitted" do
        it "is expected to reply back with the stats"
      end

      context "when the amount is 'stats'" do
        it "is expected to reply back with the stats"
      end

      context "when the amount is negative" do
        it "is expected to raise CheckFailure"
      end

      context "when the amount is 0" do
        it "is expected to raise CheckFailure"
      end

      context "when the amount is a positive number"

      context "when the amount is 'all'" do
        it "is expected to gamble all of the player's locker"
      end

      context "when the amount is 'half'" do
        it "is expected to gamble half of the player's locker"
      end

      context "when the server is not connected" do
        context "and the stats are requested" do
          it "is expected to reply back with the stats"
        end

        context "and an amount is given" do
          it "is expected to raise because the server is not connected"
        end
      end
    end
  end
end
