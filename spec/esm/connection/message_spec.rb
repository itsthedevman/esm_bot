# frozen_string_literal: true

describe ESM::Connection::Message, v2: true do
  let(:community) { ESM::Test.community }
  let(:user) { ESM::Test.user }
  let(:server) { ESM::Test.server }

  let(:input) do
    {
      id: SecureRandom.uuid,
      server_id: "esm_malden".bytes,
      type: "test",
      data: {
        type: "test_mapping",
        content: {
          # Order matters!
          array: [false, true, "2", "3.0"],
          date_time: DateTime.current,
          date: Date.today,
          hash_map: ESM::Arma::HashMap.from(key_0: false, key_1: true),
          integer: "1",
          rhash: {foo: "bar"},
          string: "string"
        }
      },
      metadata: {
        type: "empty",
        content: nil
      },
      errors: []
    }
  end

  let(:input_message) do
    described_class.new(**input.merge(
      data_type: input.dig(:data, :type),
      data: input.dig(:data, :content).clone,
      metadata_type: input.dig(:metadata, :type),
      metadata: input.dig(:metadata, :content).clone
    ))
  end

  describe ".from_string" do
    it "parses" do
      message = described_class.from_string(input.to_json)

      expect(message.id).to eq(input_message.id)
      expect(message.server_id).to eq(input_message.server_id)
      expect(message.type).to eq(input_message.type)
      expect(message.data_type).to eq(input_message.data_type)
      expect(message.metadata_type).to eq(input_message.metadata_type)
      expect(message.errors).to eq(input_message.errors)

      # Data
      expect(message.data.string).to eq(input_message.data.string)
      expect(message.data.integer).to eq(input_message.data.integer)
      expect(message.data.rhash).to eq(input_message.data.rhash)
      expect(message.data.array).to eq(input_message.data.array)
      expect(message.data.hash_map).to eq(input_message.data.hash_map)
      expect(message.data.date_time.to_s).to eq(input_message.data.date_time.to_s)
      expect(message.data.date).to eq(input_message.data.date)
    end
  end

  describe "#initialize" do
    it "requires a type" do
      expect { described_class.new(type: "test") }.not_to raise_error
    end

    it "defaults to empty" do
      message = described_class.new
      expect(message.type).to eq("event")
      expect(message.data_type).to eq("empty")
      expect(message.data.to_h).to eq({})
      expect(message.metadata_type).to eq("empty")
      expect(message.metadata.to_h).to eq({})
    end

    it "defaults the data_type to the message type if data is provided" do
      message = described_class.new(type: "data_test", data: {foo: "bar"})
      expect(message.data_type).to eq("data_test")
    end

    it "converts symbols to strings" do
      message = described_class.new(type: :test, data_type: :empty, metadata_type: :empty, server_id: server.server_id.to_sym)
      expect(message.type).to eq("test")
      expect(message.data_type).to eq("empty")
      expect(message.metadata_type).to eq("empty")
      expect(message.server_id).to eq(server.server_id)
    end
  end

  describe "#to_s/#to_json" do
    it "is valid json" do
      expect(input_message.to_s).to eq(input.to_json)
    end
  end

  describe "#to_h" do
    it "is a valid hash" do
      expect(input_message.to_h).to eq(input)
    end
  end

  describe "#on_error" do
    let(:message) do
      ESM::Connection::Message.new(
        server_id: Faker::ESM.server_id,
        type: "testing",
        data_type: "data_test",
        data: {foo: "bar"},
        metadata_type: "metadata_test",
        metadata: {bar: "baz"}
      )
    end

    it "handles codes" do
      current_user = double("user")
      allow(current_user).to receive(:mention).and_return(user.mention)

      command = double("command")
      allow(command).to receive(:current_user).and_return(current_user)
      allow(command).to receive(:target_user).and_return(nil)

      # Needed for mention
      message.locals = {command: command}
      message.add_error(type: "code", content: "test")

      embed = message.send(:on_error, message, nil)
      expect(embed.description).to eq("#{current_user.mention} | #{message.id} | #{message.server_id} | #{message.type} | #{message.data_type} | #{message.metadata_type} | #{message.data.foo} | #{message.metadata.bar}")
    end

    it "handles messages" do
      message.add_error(type: "message", content: "Hello World")
      embed = message.send(:on_error, message, nil)

      expect(embed.description).to eq("Hello World")
    end
  end
end
