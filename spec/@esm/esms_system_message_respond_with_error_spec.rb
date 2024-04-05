# frozen_string_literal: true

describe "ESMs_system_message_respond_withError", :requires_connection, v2: true do
  include_context "connection"

  context "when errors are provided" do
    it "contains the errors" do
      original_message = ESM::Message.event

      promise = server.connection
        .write(type: :message, id: original_message.id, content: nil)
        .reset_promise

      execute_sqf!(
        <<~SQF
          [
            "#{original_message.id}",
            "event",
            "empty",
            [],
            "empty",
            [],
            [["code", "ERROR_CODE"], ["message", "An error message"]]
          ] call ESMs_system_message_respond_to;
        SQF
      )

      # Now we can read the response from the SQF
      response = promise.wait_for_response
      expect(response.fulfilled?).to be(true)

      message = ESM::Message.from_string(response.value)

      expect(message.type).to eq(:event)
      expect(message.id).to eq(original_message.id)
      expect(message.data_type).to eq(:empty)
      expect(message.data).to eq({})
      expect(message.metadata_type).to eq(:empty)
      expect(message.metadata).to eq({})

      errors = message.errors.map(&:to_h)
      expect(errors).to include({type: :code, content: "ERROR_CODE"})
      expect(errors).to include({type: :message, content: "An error message"})
    end
  end
end
