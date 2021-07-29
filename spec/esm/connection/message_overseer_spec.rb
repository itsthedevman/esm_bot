# frozen_string_literal: true

describe ESM::Connection::MessageOverseer do
  let!(:overseer) { ESM::Connection::Server.instance.message_overseer }
  let!(:message) { ESM::Connection::Message.new(type: "test") }

  describe "#watch" do
    it "adds the message to the watch list" do
      expect { overseer.watch(message) }.not_to raise_error
      expect(overseer.instance_variable_get("@mailbox").size).to eq(1)
    end

    it "times out and calls on_error" do
      message.add_callback(:on_error) do |incoming, _|
        expect(incoming.id).to eq(message.id)
      end

      expect { overseer.watch(message, expires_at: Time.now) }.not_to raise_error

      sleep(0.4) # Minimum amount of time
      expect(message.errors?).to be(true)
      expect(message.errors.first.type).to eq("code")
      expect(message.errors.first.content).to eq("message_undeliverable")
    end
  end

  describe "#retrieve" do
    it "returns the message based on its id" do
      expect { overseer.watch(message) }.not_to raise_error

      expect(overseer.retrieve(message.id)).to eq(message)
    end
  end
end
