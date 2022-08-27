# frozen_string_literal: true

describe "ESMs_object_message_respond_to", requires_connection: true, v2: true do
  include_examples "connection"

  it "acknowledges the message" do
    success = false
    message = ESM::Connection::Message.new(type: :test)

    message.add_callback(:on_response) do |inbound, outbound|
      expect(outbound.type).to eq("test")
      expect(inbound.type).to eq("event")

      expect(inbound.id).to eq(message.id)
      expect(outbound.id).to eq(message.id)

      expect(inbound.data_type).to eq("empty")
      expect(inbound.data).to eq(nil)

      expect(inbound.metadata_type).to eq("empty")
      expect(inbound.metadata).to eq(nil)

      expect(inbound.errors).to eq([])

      success = true
    end

    # Needed for the message cycle to properly complete
    connection.tcp_server.message_overseer.watch(message)

    execute_sqf!(
      <<~SQF
        ["#{message.id}"] call ESMs_object_message_respond_to;
      SQF
    )

    expect(success).to be(true), "Asynchronous response callback experienced an issue - Check logs for \"terminated with exception\""
  end

  it "on_error is triggered when errors" do
    success = false
    message = ESM::Connection::Message.new(type: :test)

    message.add_callback(:on_error) do |inbound, outbound|
      expect(outbound.type).to eq("test")
      expect(inbound.type).to eq("event")

      expect(inbound.id).to eq(message.id)
      expect(outbound.id).to eq(message.id)

      expect(inbound.data_type).to eq("empty")
      expect(inbound.data).to eq(nil)

      expect(inbound.metadata_type).to eq("empty")
      expect(inbound.metadata).to eq(nil)

      expect(outbound.errors).to eq([])

      errors = inbound.errors.map(&:to_h)
      expect(errors).to include({type: "code", content: "ERROR_CODE"})
      expect(errors).to include({type: "message", content: "An error message"})

      success = true
    end

    # Needed for the message cycle to properly complete
    connection.tcp_server.message_overseer.watch(message)

    execute_sqf!(
      <<~SQF
        ["#{message.id}", "event", "empty", [], "empty", [], [["code", "ERROR_CODE"], ["message", "An error message"]]] call ESMs_object_message_respond_to;
      SQF
    )

    expect(success).to be(true), "Asynchronous response callback experienced an issue - Check logs for \"terminated with exception\""
  end
end
