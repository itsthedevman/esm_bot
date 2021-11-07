# frozen_string_literal: true

describe ESM::Connection::Server do
  let(:connection_server) { described_class.instance }
  let(:message) { ESM::Connection::Message.new(type: "test", data: { foo: "bar" }, data_type: "data_test") }

  describe "#on_message" do
    it "triggers on_error if message contains errors" do
      outgoing_message = message.dup
      outgoing_message.add_error(type: "code", content: "default")

      # Remove the default callback and set a new one
      outgoing_message.add_callback(:on_error) do |_incoming, outgoing|
        expect(outgoing.errors.first.to_h).to eql({ type: "code", content: "default" })
      end

      # The overseer needs to know about this message
      connection_server.message_overseer.watch(outgoing_message)

      expect { connection_server.send(:on_message, message) }.not_to raise_error
    end
  end

  # fire(message, to:, forget: false, wait: false)
  describe "#fire", requires_connection: true do
    include_context "connection"

    let(:server) { ESM::Test.server }

    before :each do
      ESM::Test.store_server_messages = true
    end

    it "sends a message" do
      expect { connection_server.fire(message, to: server.server_id) }.not_to raise_error

      outgoing_message = ESM::Test.server_messages.first
      expect(outgoing_message).not_to be_nil

      expect(outgoing_message.destination).to eq(server.server_id)
      expect(outgoing_message.content).to eq(message)
    end

    it "sends a message and waits for the reply" do
      outgoing_message = ESM::Connection::Message.new(id: message.id, type: "test")
      message.server_id = server.server_id

      thread = Thread.new do
        response = nil
        expect { response = connection_server.fire(outgoing_message, to: server.server_id, wait: true) }.not_to raise_error

        expect(response).not_to be_nil
        expect(response.type).to eq("test")
        expect(response.data_type).to eq("data_test")
      end

      sleep(0.2)

      expect(connection_server.message_overseer.size).to eq(1)
      expect { connection_server.send(:on_message, message) }.not_to raise_error
      expect(connection_server.message_overseer.size).to eq(0)

      thread.join

      message = ESM::Test.server_messages.first
      expect(message).not_to be_nil

      expect(message.destination).to eq(server.server_id)
      expect(message.content.to_h).to eq(outgoing_message.to_h)
    end
  end
end
