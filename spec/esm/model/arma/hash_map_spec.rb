# frozen_string_literal: true

describe ESM::Arma::HashMap do
  describe ".new" do
    it "normalizes (Input is String)" do
      input = <<~STRING
        [
          ["key_1", "string value"],
          ["key_2", 1],
          ["key_3", 2.5],
          ["key_4", [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]]],
          [
            "key_5",
            [
              ["key_6", true],
              ["key_7", false]
            ]
          ]
        ]
      STRING

      conversion_result = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], { eight: false }],
        key_5: { key_6: true, key_7: false }
      }

      hash_map = described_class.new(input)
      expect(hash_map).to eq(conversion_result)
    end

    it "normalizes (Input is Array)" do
      input = [
        ["key_1", "string value"],
        ["key_2", 1],
        ["key_3", 2.5],
        ["key_4", [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]]],
        [
          "key_5",
          [
            ["key_6", true],
            ["key_7", false]
          ]
        ]
      ]

      conversion_result = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], { eight: false }],
        key_5: { key_6: true, key_7: false }
      }

      hash_map = described_class.new(input)
      expect(hash_map).to eq(conversion_result)
    end

    it "normalizes (Input is OpenStruct)" do
      input = OpenStruct.new(
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]],
        key_5: [
          ["key_6", true],
          ["key_7", false]
        ]
      )

      conversion_result = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], { eight: false }],
        key_5: { key_6: true, key_7: false }
      }

      hash_map = described_class.new(input)
      expect(hash_map).to eq(conversion_result)
    end

    it "normalizes (Input is Hash)" do
      input = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]],
        key_5: [
          [
            ["key_6", true],
            ["key_7", false]
          ],
          true
        ],
        key_6: :symbol
      }

      conversion_result = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], { eight: false }],
        key_5: [{ key_6: true, key_7: false }, true],
        key_6: "symbol"
      }

      hash_map = described_class.new(input)
      expect(hash_map).to eq(conversion_result)
    end
  end

  describe "#valid_array_hash?" do
    it "be valid" do
      hash_map = described_class.new
      input = [
        ["key_1", 1],
        ["key_2", [1, 2, 3, 4, 5]],
        ["key_3", "three"]
      ]

      expect(hash_map.send(:valid_array_hash?, input)).to be(true)
    end

    it "not be valid" do
      hash_map = described_class.new

      input = [1, 2, 3, 4, 5]
      expect(hash_map.send(:valid_array_hash?, input)).to be(false)

      input = [["key_1", 2], "key_2"]
      expect(hash_map.send(:valid_array_hash?, input)).to be(false)

      input = [["key_1", 2], [2, 3], ["key_4", "five"]]
      expect(hash_map.send(:valid_array_hash?, input)).to be(false)

      input = [["key_1", 2], ["key_3", 4], ["key_5"]]
      expect(hash_map.send(:valid_array_hash?, input)).to be(false)

      input = ["key_1", 2]
      expect(hash_map.send(:valid_array_hash?, input)).to be(false)
    end

    it "be valid (duplicated keys)" do
      hash_map = described_class.new
      input = [
        ["key_1", 1],
        ["key_2", [1, 2, 3, 4, 5]],
        ["key_2", "three"]
      ]

      expect(hash_map.send(:valid_array_hash?, input)).to be(true)
    end
  end

  describe "#to_a" do
    it "converts" do
      input = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]],
        key_5: [
          [
            ["key_6", true],
            ["key_7", false]
          ],
          true
        ]
      }

      expected = [
        ["key_1", "string value"],
        ["key_2", 1],
        ["key_3", 2.5],
        ["key_4", [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]]],
        [
          "key_5",
          [
            [
              ["key_6", true],
              ["key_7", false]
            ],
            true
          ]
        ]
      ]

      hash_map = described_class.new(input)

      expect(hash_map.to_a).to eq(expected)
    end
  end

  describe "#to_json" do
    it "converts" do
      input = {
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]],
        key_5: [
          [
            ["key_6", true],
            ["key_7", false]
          ],
          true
        ]
      }

      expected = [
        ["key_1", "string value"],
        ["key_2", 1],
        ["key_3", 2.5],
        ["key_4", [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]]],
        [
          "key_5",
          [
            [
              ["key_6", true],
              ["key_7", false]
            ],
            true
          ]
        ]
      ].to_json

      hash_map = described_class.new(input)

      expect(hash_map.to_json).to eq(expected)
    end
  end
end
