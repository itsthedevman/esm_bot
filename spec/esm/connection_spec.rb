# frozen_string_literal: true

describe ESM::Connection, v2: true, requires_connection: true do
  include_examples "connection"

  let!(:server) { ESM::Test.server }
  let!(:connection_server) { ESM::Connection::Server.instance }
  let(:message) { ESM::Connection::Message.new(type: :test, data: {foo: "bar"}, data_type: :data_test) }

  after :each do
    ESM::Connection::Server.instance.message_overseer.remove_all!
  end

  describe "#send_message" do
    before :each do
      ESM::Test.block_outbound_messages = true
    end

    it "accepts a hash" do
      outgoing_message = connection.send_message(type: :test, data: {foo: "bar"}, data_type: :data_test)

      message = ESM::Test.outbound_server_messages.first
      expect(message).not_to be_nil

      expect(message.content).to eq(outgoing_message)
    end

    it "accepts a message" do
      outgoing_message = connection.send_message(message)

      server_message = ESM::Test.outbound_server_messages.first
      expect(server_message).not_to be_nil

      expect(server_message.content).to eq(outgoing_message)
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
            server_start_time: DateTime.now,
            extension_version: "2.0.0",
            vg_enabled: false,
            vg_max_sizes: [-1, 5, 8, 11, 13, 15, 18, 21, 25, 28]
          }
        )

      expect { connection.on_open(incoming_message) }.not_to raise_error
    end
  end

  describe "#on_message" do
    it "acknowledges the message" do
      incoming_message = ESM::Connection::Message.new(type: "test")

      message.add_callback(:on_response) do |_, outgoing|
        expect(outgoing).to eq(message)
        expect(outgoing.delivered?).to be(true)
      end

      expect { connection.on_message(incoming_message, message) }.not_to raise_error
    end
  end

  # Not implemented
  # describe "#on_close"

  # See specs above: #on_message -> Message processing -> Type: event
  # describe "#on_event"
end
