# frozen_string_literal: true

describe ESM::Connection::Message do
  let(:input) do
    {
      id: SecureRandom.uuid,
      server_id: "esm_malden".bytes,
      resource_id: nil,
      type: "test",
      data: {
        type: "test_mapping",
        content: {
          string: "string",
          integer: 1,
          rhash: { foo: "bar" }, # Because OStruct has a method called #hash
          array: [false, true, "2", 3.0],
          hash_map: ESM::Arma::HashMap.new(key_0: false, key_1: true),
          date_time: DateTime.current,
          date: Date.today
        }
      },
      metadata: {
        type: "empty",
        content: {}
      },
      errors: []
    }
  end

  let(:input_message) do
    described_class.new(**input.merge(
      data_type: input.dig(:data, :type),
      data: input.dig(:data, :content),
      metadata_type: input.dig(:metadata, :type),
      metadata: input.dig(:metadata, :content)
    ))
  end

  describe ".from_string" do
    it "parses" do
      message = described_class.from_string(input.to_json)

      expect(message.id).to eq(input_message.id)
      expect(message.server_id).to eq(input_message.server_id)
      expect(message.resource_id).to eq(input_message.resource_id)
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

  describe ".convert_types" do
    def mapping(data, type)
      data.each_with_object({}) { |pair, out| out[pair.first] = type }
    end

    it "converts (String)" do
      input = { string: "Hello World", bytes: [1, 2, 3, 4, 5, 6, 7], bool: true }
      expectation = { string: "Hello World", bytes: "[1, 2, 3, 4, 5, 6, 7]", bool: "true" }

      expect(
        described_class.convert_types(input, type: "test", mapping: mapping(input, "String"))
      ).to eq(expectation)
    end

    it "converts (Integer)" do
      input = { int: 1, float: 4.0, string: "7" }
      expectation = { int: 1, float: 4, string: 7 }

      expect(
        described_class.convert_types(input, type: "test", mapping: mapping(input, "Integer"))
      ).to eq(expectation)
    end

    it "converts (Hash)" do
      input = { hash: { foo: "bar" }, json: { foo: "bar" }.to_json }
      expectation = { hash: { foo: "bar" }, json: { foo: "bar" } }

      expect(
        described_class.convert_types(input, type: "test", mapping: mapping(input, "Hash"))
      ).to eq(expectation)
    end

    it "converts (Array)" do
      input = { array: [1, 2, 3, "four"], hash: { foo: "bar" } }
      expectation = { array: [1, 2, 3, "four"], hash: [[:foo, "bar"]] }

      expect(
        described_class.convert_types(input, type: "test", mapping: mapping(input, "Array"))
      ).to eq(expectation)
    end

    it "converts (HashMap)" do
      input = {
        hash_map: [
          ["1", 2],
          ["three", "4"],
          ["four", [["five", true]]]
        ].to_json
      }
      expectation = { hash_map: { "1": 2, three: "4", four: { five: true } } }

      expect(
        described_class.convert_types(input, type: "test", mapping: mapping(input, "HashMap"))
      ).to eq(expectation)
    end

    it "converts (DateTime)" do
      current_time = DateTime.current
      input = { date_time: current_time, string: current_time.to_s }
      output = described_class.convert_types(input, type: "test", mapping: mapping(input, "DateTime"))

      # Can't directly compare two DateTime objects
      expect(output[:date_time].to_s).to eq(current_time.to_s)
      expect(output[:string].to_s).to eq(current_time.to_s)
    end

    it "converts (Date)" do
      input = { date: Date.today, string: Date.today.to_s }
      expectation = { date: Date.today, string: Date.today }

      expect(
        described_class.convert_types(input, type: "test", mapping: mapping(input, "Date"))
      ).to eq(expectation)
    end

    it "raises (failed to find type in the global mapping)" do
      input = { foo: "bar" }

      expect { described_class.convert_types(input, type: "test", mapping: {}) }.to raise_error("Failed to find type \"test\" in \"message_type_mapping.yml\"")
    end

    it "raises (failed to find key in the mapping)" do
      input = { foo: "bar" }

      expect { described_class.convert_types(input, type: "test", mapping: { test: {} }) }.to raise_error("Failed to find key \"foo\" in mapping for \"test\"")
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
end
