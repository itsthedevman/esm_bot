# frozen_string_literal: true

describe ESM::Connection::Server, v2: true do
  include_context "connection"

  describe "#check_waiting_room" do
    context "when the client has not been in the waiting room long enough to time out" do
      it "does not time out the client" do
        connection_server.waiting_room << ESM::Connection::Client.new(nil, nil, nil)

        expect(connection_server.waiting_room.size).to eq(1)

        connection_server.send(:check_waiting_room)

        expect(connection_server.waiting_room.size).to eq(1)
      end
    end

    context "when the client has been in the waiting room for too long" do
      before do
        ESM.config.connection_server.disconnect_after = 0.5
      end

      it "times out the client" do
        client = ESM::Connection::Client.new(nil, nil, nil)
        expect(client).to receive(:close)

        connection_server.waiting_room << client
        expect(connection_server.waiting_room.size).to eq(1)

        sleep(1)

        connection_server.send(:check_waiting_room)
        expect(connection_server.waiting_room.size).to eq(0)
      end
    end
  end
end
