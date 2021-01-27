# frozen_string_literal: true

describe ESM::BotCommand do
  let!(:server) { ESM::Test.server }
  let!(:wsc) { WebsocketClient.new(server) }
  let(:connection) { ESM::Websocket.connections[server.server_id] }

  def bot_command(received_data)
    ESM::BotCommand.new(connection: connection, received_data: received_data)
  end

  before :each do
    wait_for { wsc.connected? }.to be(true)
  end

  after :each do
    wsc.disconnect!
  end

  describe "#normalize_parameters" do
    it "should normalize (Input is ArrayPairs)" do
      parameters = <<~STRING
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

      command = bot_command(OpenStruct.new(parameters: parameters))

      conversion_result = OpenStruct.new(
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], OpenStruct.new(eight: false)],
        key_5: OpenStruct.new(key_6: true, key_7: false)
      )

      command.send(:normalize_parameters)
      expect(command.parameters.table).to eql(conversion_result.table)
    end

    it "should normalize (Input is OpenStruct)" do
      parameters = OpenStruct.new(
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], [["eight", false]]],
        key_5: [
          ["key_6", true],
          ["key_7", false]
        ]
      )

      command = bot_command(OpenStruct.new(parameters: parameters))

      conversion_result = OpenStruct.new(
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], OpenStruct.new(eight: false)],
        key_5: OpenStruct.new(key_6: true, key_7: false)
      )

      command.send(:normalize_parameters)
      expect(command.parameters.table).to eql(conversion_result.table)
    end

    it "should normalize (Input is Hash)" do
      parameters = {
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

      command = bot_command(OpenStruct.new(parameters: parameters))

      conversion_result = OpenStruct.new(
        key_1: "string value",
        key_2: 1,
        key_3: 2.5,
        key_4: [1, "two", ["three", 4, 5], ["six", 7], OpenStruct.new(eight: false)],
        key_5: [OpenStruct.new(key_6: true, key_7: false), true]
      )

      command.send(:normalize_parameters)
      expect(command.parameters.table).to eql(conversion_result.table)
    end
  end

  describe "#valid_array_hash?" do
    it "should be valid" do
      command = bot_command(OpenStruct.new(parameters: "{}"))
      input = [
        ["key_1", 1],
        ["key_2", [1, 2, 3, 4, 5]],
        ["key_3", "three"]
      ]

      expect(command.send(:valid_array_hash?, input)).to be(true)
    end

    it "should not be valid" do
      command = bot_command(OpenStruct.new(parameters: "{}"))

      input = [1, 2, 3, 4, 5]
      expect(command.send(:valid_array_hash?, input)).to be(false)

      input = [["key_1", 2], "key_2"]
      expect(command.send(:valid_array_hash?, input)).to be(false)

      input = [["key_1", 2], [2, 3], ["key_4", "five"]]
      expect(command.send(:valid_array_hash?, input)).to be(false)

      input = [["key_1", 2], ["key_3", 4], ["key_5"]]
      expect(command.send(:valid_array_hash?, input)).to be(false)

      input = ["key_1", 2]
      expect(command.send(:valid_array_hash?, input)).to be(false)
    end

    it "should be valid (duplicated keys)" do
      command = bot_command(OpenStruct.new(parameters: "{}"))
      input = [
        ["key_1", 1],
        ["key_2", [1, 2, 3, 4, 5]],
        ["key_2", "three"]
      ]

      expect(command.send(:valid_array_hash?, input)).to be(true)
    end
  end
end
