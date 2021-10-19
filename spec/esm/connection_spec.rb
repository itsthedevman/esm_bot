# frozen_string_literal: true

describe ESM::Connection do
  let!(:connection_server) { ESM::Connection::Server.instance }
  let!(:server) { ESM::Test.server }
  let!(:connection) { described_class.new(connection_server, server.server_id) }
  let(:message) { ESM::Connection::Message.new(type: "test", data: { foo: "bar" }, data_type: "test") }

  describe "#send_message" do
    it "accepts a hash" do
      outgoing_message = connection.send_message(type: "test", data: { foo: "bar" }, data_type: "test")
      sleep(0.1) # Give the tcp_server a chance to pick up the message. It's fast.
      expect(ESM::Test.redis.llen("test")).to eq(1)

      json = ESM::Test.redis.lpop("test")
      expect(json).to eq(outgoing_message.to_s)
    end

    it "accepts a message" do
      outgoing_message = connection.send_message(message)
      expect(message).to eq(outgoing_message)

      sleep(0.1)
      expect(ESM::Test.redis.llen("test")).to eq(1)

      json = ESM::Test.redis.lpop("test")
      expect(json).to eq(outgoing_message.to_s)
    end
  end

  describe "#on_open" do
    it "runs ESM::Event::ServerInitialization" do
      incoming_message =
        ESM::Connection::Message.new(
          type: "init",
          data_type: "init",
          data: {
            server_name: server.server_name,
            price_per_object: 10,
            territory_lifetime: 7,
            territory_data: "[]",
            server_start_time: DateTime.now
          }
        )

      expect { connection.on_open(incoming_message) }.not_to raise_error
    end
  end

  describe "#on_message" do
    describe "Type: Event" do
      it "acknowledges the message" do
        incoming_message = ESM::Connection::Message.new(type: "event")

        message.add_callback(:on_response) do |_, outgoing|
          expect(outgoing).to eq(message)
          expect(outgoing.delivered?).to be(true)
        end

        expect { connection.on_message(incoming_message, message) }.not_to raise_error
      end
    end

    it "Invalid type" do
      incoming_message = ESM::Connection::Message.new(type: "uhhhh")
      expect { connection.on_message(incoming_message, message) }.to raise_error(
        StandardError, "[#{incoming_message.id}] Connection#on_message does not implement this type: \"#{incoming_message.type}\""
      )
    end
  end

  # Not implemented
  # describe "#on_close"

  # See specs above: #on_message -> Message processing -> Type: event
  # describe "#on_event"
end
