# frozen_string_literal: true

describe ESM::Connection::Server do
  let!(:connection_server) { described_class.instance }
  let(:message) { ESM::Connection::Message.new(type: "test", data: { foo: "bar" }, data_type: "test") }

  describe "#on_message" do
    it "triggers on_error if message contains errors" do
      outgoing_message = message.dup
      outgoing_message.add_error(type: "code", content: "default")

      # Remove the default callback and set a new one
      outgoing_message.remove_callback(:on_error, :on_error)
      outgoing_message.add_callback(:on_error) do |_, outgoing|
        expect(outgoing.errors.first.to_h).to eql({ type: "code", content: "default" })
      end

      # The overseer needs to know about this message
      connection_server.message_overseer.watch(outgoing_message)

      expect { connection_server.send(:on_message, message) }.not_to raise_error
    end
  end
end
