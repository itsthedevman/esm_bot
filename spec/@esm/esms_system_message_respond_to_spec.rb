# frozen_string_literal: true

describe "ESMs_system_message_respond_to", :requires_connection, v2: true do
  include_context "connection"

  it "acknowledges the message" do
    original_message = ESM::Message.event

    # #reset_promise recreates the promise to remove any existing #then callbacks
    # This is needed because we're simulating an existing message that is being replied to
    # and we don't want to trigger the message being sent to the client
    promise = server.connection
      .write(type: :message, id: original_message.id, content: nil)
      .reset_promise

    execute_sqf!(
      <<~SQF
        ["#{original_message.id}"] call ESMs_system_message_respond_to;
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
    expect(message.errors).to eq([])
  end
end
