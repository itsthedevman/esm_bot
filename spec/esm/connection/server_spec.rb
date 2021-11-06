# frozen_string_literal: true

describe ESM::Connection::Server, requires_connection: true do
  let(:connection_server) { described_class.instance }
  let(:message) { ESM::Connection::Message.new(type: "test", data: { foo: "bar" }, data_type: "data_test") }

  let(:server) { ESM::Test.server }

  before :each do
    ESM::Test.store_server_messages = true
  end

  describe "#on_message" do
    it "triggers on_error if message contains errors" do
      outgoing_message = message.dup
      outgoing_message.add_error(type: "code", content: "default")

      # Remove the default callback and set a new one
      outgoing_message.add_callback(:on_error) do |_, outgoing|
        expect(outgoing.errors.first.to_h).to eql({ type: "code", content: "default" })
      end

      # The overseer needs to know about this message
      connection_server.message_overseer.watch(outgoing_message)

      expect { connection_server.send(:on_message, message) }.not_to raise_error
    end
  end

  # fire(message, to:, forget: false, wait: false)
  describe "#fire" do
    it "sends a message" do
      expect { connection_server.fire(message, to: server.server_id) }.not_to raise_error

      outgoing_message = ESM::Test.server_messages.first
      expect(outgoing_message).not_to be_nil

      expect(outgoing_message.destination).to eq(server.server_id)
      expect(outgoing_message.content).to eq(message)
    end

    it "sends a message and waits for the reply" do
      thread = Thread.new do
        expect { connection_server.fire(message, to: server.server_id, wait: true) }.not_to raise_error
      end

      sleep(0.2)

      expect(connection_server.message_overseer.size)
      message.run_callback(:on_response, message, nil)

      thread.join

      outgoing_message = ESM::Test.server_messages.first
      expect(outgoing_message).not_to be_nil

      expect(outgoing_message.destination).to eq(server.server_id)
      expect(outgoing_message.content).to eq(message)
    end
  end
end
