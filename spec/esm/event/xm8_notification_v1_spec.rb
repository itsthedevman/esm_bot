# frozen_string_literal: true

describe ESM::Event::Xm8NotificationV1 do
  let!(:community) { ESM::Test.community }
  let!(:server) { ESM::Test.server }
  let!(:wsc) { WebsocketClient.new(server) }
  let!(:user) { ESM::Test.user }
  let!(:second_user) { ESM::Test.second_user }
  let!(:recipients) { [user.steam_uid, second_user.steam_uid] }
  let(:territory) { TerritoryGenerator.generate.to_ostruct }
  let(:send_notification) do
    expect { wsc.send_xm8_notification(attributes) }.not_to raise_error
  end

  before :each do
    wait_for { wsc.connected? }.to be(true)
  end

  after :each do
    wsc.disconnect!
  end

  describe "Bad Data" do
    it "should log invalid type"
    it "should log invalid attributes"
  end

  # <OpenStruct type="base-raid", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#base-raid" do
    let(:attributes) do
      {
        type: "base-raid",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "should send to all" do
      community.update(log_xm8_event: false)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(2)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(2)

      # Check the embeds
      embed = ESM::Test.messages.first.second
      expect(embed.title).to eq("Oh noes! #{attributes[:message]} is being raided!")
      expect(embed.description).to eq("Hop on quick, **#{attributes[:message]}** (`#{attributes[:id]}`) is being raided")

      embed = ESM::Test.messages.second.second
      expect(embed.title).to eq("Oh noes! #{attributes[:message]} is being raided!")
      expect(embed.description).to eq("Hop on quick, **#{attributes[:message]}** (`#{attributes[:id]}`) is being raided")
    end

    it "should log" do
      community.update(log_xm8_event: true)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(3)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(3)

      # Check the embed
      embed = ESM::Test.messages.third.second
      expect(embed.title).to eq("(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`")
      expect(embed.description).to eq("**Title:**\nOh noes! #{attributes[:message]} is being raided!\n**Description:**\nHop on quick, **#{attributes[:message]}** (`#{attributes[:id]}`) is being raided")
    end
  end

  # <OpenStruct type="flag-restored", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#flag-restored" do
    let(:attributes) do
      {
        type: "flag-restored",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "should send to all" do
      community.update(log_xm8_event: false)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(2)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(2)

      # Check the embeds
      embed = ESM::Test.messages.first.second
      expect(embed.title).to eq("Flag Restored `(#{attributes[:id]})`")
      expect(embed.description).to eq("**#{attributes[:message]}'s** flag has been restored! Good job getting it back!")

      embed = ESM::Test.messages.second.second
      expect(embed.title).to eq("Flag Restored `(#{attributes[:id]})`")
      expect(embed.description).to eq("**#{attributes[:message]}'s** flag has been restored! Good job getting it back!")
    end

    it "should log" do
      community.update(log_xm8_event: true)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(3)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(3)

      # Check the embed
      embed = ESM::Test.messages.third.second
      expect(embed.title).to eq("(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`")
      expect(embed.description).to eq("**Title:**\nFlag Restored `(#{attributes[:id]})`\n**Description:**\n**#{attributes[:message]}'s** flag has been restored! Good job getting it back!")
    end
  end

  # <OpenStruct type="flag-steal-started", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#flag-steal-started" do
    let(:attributes) do
      {
        type: "flag-steal-started",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "should send to all" do
      community.update(log_xm8_event: false)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(2)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(2)

      # Check the embeds
      embed = ESM::Test.messages.first.second
      expect(embed.title).to eq("Flag Steal Started `(#{attributes[:id]})`")
      expect(embed.description).to eq("Someone is trying to steal **#{attributes[:message]}'s** flag!")

      embed = ESM::Test.messages.second.second
      expect(embed.title).to eq("Flag Steal Started `(#{attributes[:id]})`")
      expect(embed.description).to eq("Someone is trying to steal **#{attributes[:message]}'s** flag!")
    end

    it "should log" do
      community.update(log_xm8_event: true)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(3)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(3)

      # Check the embed
      embed = ESM::Test.messages.third.second
      expect(embed.title).to eq("(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`")
      expect(embed.description).to eq("**Title:**\nFlag Steal Started `(#{attributes[:id]})`\n**Description:**\nSomeone is trying to steal **#{attributes[:message]}'s** flag!")
    end
  end

  # <OpenStruct type="flag-stolen", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#flag-stolen" do
    let(:attributes) do
      {
        type: "flag-stolen",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "should send to all" do
      community.update(log_xm8_event: false)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(2)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(2)

      # Check the embeds
      embed = ESM::Test.messages.first.second
      expect(embed.title).to eq("Flag Stolen `(#{attributes[:id]})`")
      expect(embed.description).to eq("**#{attributes[:message]}'s** flag has been stolen! Go get it back!")

      embed = ESM::Test.messages.second.second
      expect(embed.title).to eq("Flag Stolen `(#{attributes[:id]})`")
      expect(embed.description).to eq("**#{attributes[:message]}'s** flag has been stolen! Go get it back!")
    end

    it "should log" do
      community.update(log_xm8_event: true)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(3)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(3)

      # Check the embed
      embed = ESM::Test.messages.third.second
      expect(embed.title).to eq("(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`")
      expect(embed.description).to eq("**Title:**\nFlag Stolen `(#{attributes[:id]})`\n**Description:**\n**#{attributes[:message]}'s** flag has been stolen! Go get it back!")
    end
  end

  # <OpenStruct type="grind-started", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test",id="awesome">
  describe "#grind-started" do
    let(:attributes) do
      {
        type: "grind-started",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "should send to all" do
      community.update(log_xm8_event: false)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(2)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(2)

      # Check the embeds
      embed = ESM::Test.messages.first.second
      expect(embed.title).to eq("Grinding Started `(#{attributes[:id]})`")
      expect(embed.description).to eq("Some scalliwag is tryna grind yer locks! **#{attributes[:message]}** is being raided!")

      embed = ESM::Test.messages.second.second
      expect(embed.title).to eq("Grinding Started `(#{attributes[:id]})`")
      expect(embed.description).to eq("Some scalliwag is tryna grind yer locks! **#{attributes[:message]}** is being raided!")
    end

    it "should log" do
      community.update(log_xm8_event: true)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(3)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(3)

      # Check the embed
      embed = ESM::Test.messages.third.second
      expect(embed.title).to eq("(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`")
      expect(embed.description).to eq("**Title:**\nGrinding Started `(#{attributes[:id]})`\n**Description:**\nSome scalliwag is tryna grind yer locks! **#{attributes[:message]}** is being raided!")
    end
  end

  # <OpenStruct type="hack-started", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#hack-started" do
    let(:attributes) do
      {
        type: "hack-started",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "should send to all" do
      community.update(log_xm8_event: false)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(2)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(2)

      # Check the embeds
      embed = ESM::Test.messages.first.second
      expect(embed.title).to eq("Hacking Started `(#{attributes[:id]})`")
      expect(embed.description).to eq("H4x0rs are trying to get into your stuff! **#{attributes[:message]}** is being robbed! ")

      embed = ESM::Test.messages.second.second
      expect(embed.title).to eq("Hacking Started `(#{attributes[:id]})`")
      expect(embed.description).to eq("H4x0rs are trying to get into your stuff! **#{attributes[:message]}** is being robbed! ")
    end

    it "should log" do
      community.update(log_xm8_event: true)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(3)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(3)

      # Check the embed
      embed = ESM::Test.messages.third.second
      expect(embed.title).to eq("(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`")
      expect(embed.description).to eq("**Title:**\nHacking Started `(#{attributes[:id]})`\n**Description:**\nH4x0rs are trying to get into your stuff! **#{attributes[:message]}** is being robbed! ")
    end
  end

  # <OpenStruct type="protection-money-paid", recipients="{ \"r\": [\"76561198037177305\",\"76561198025434405\"] }", message="ESM Test", id="awesome">
  describe "#protection-money-paid" do
    let(:attributes) do
      {
        type: "protection-money-paid",
        recipients: recipients,
        message: territory.territory_name,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "should send to all" do
      community.update(log_xm8_event: false)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(2)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(2)

      # Check the embeds
      # attributes[:message]
      # attributes[:id]
      embed = ESM::Test.messages.first.second
      expect(embed.title).to eq("Protection Money Paid `(#{attributes[:id]})`")
      expect(embed.description).to eq("**#{attributes[:message]}'s** protection money has been paid")

      embed = ESM::Test.messages.second.second
      expect(embed.title).to eq("Protection Money Paid `(#{attributes[:id]})`")
      expect(embed.description).to eq("**#{attributes[:message]}'s** protection money has been paid")
    end

    it "should log" do
      community.update(log_xm8_event: true)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(3)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(3)

      # Check the embed
      embed = ESM::Test.messages.third.second
      expect(embed.title).to eq("(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`")
      expect(embed.description).to eq("**Title:**\nProtection Money Paid `(#{attributes[:id]})`\n**Description:**\n**#{attributes[:message]}'s** protection money has been paid")
    end
  end

  # <OpenStruct type="marxet-item-sold", recipients="{ \"r\": [\"76561198037177305\"] }", message="{ \"item\": \"MX 6.5mm\", \"amount\": \"1000\" }">
  describe "#marxet-item-sold" do
    let(:attributes) do
      {
        type: "marxet-item-sold",
        recipients: recipients,
        message: { item: Faker::Book.title, amount: Faker::Number.between(from: 1, to: 10_000_000) }.to_json,
        id: territory.esm_custom_id || territory.id
      }
    end

    it "should send to all" do
      community.update(log_xm8_event: false)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(2)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(2)

      # Check the embeds
      values = attributes[:message].to_ostruct
      embed = ESM::Test.messages.first.second
      expect(embed.title).to eq("Item sold on MarXet")
      expect(embed.description).to eq("You just sold **#{values.item}** for **#{values.amount}** poptabs")

      embed = ESM::Test.messages.second.second
      expect(embed.title).to eq("Item sold on MarXet")
      expect(embed.description).to eq("You just sold **#{values.item}** for **#{values.amount}** poptabs")
    end

    it "should log" do
      community.update(log_xm8_event: true)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(3)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(3)

      # Check the embed
      values = attributes[:message].to_ostruct
      embed = ESM::Test.messages.third.second
      expect(embed.title).to eq("(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`")
      expect(embed.description).to eq("**Title:**\nItem sold on MarXet\n**Description:**\nYou just sold **#{values.item}** for **#{values.amount}** poptabs")
    end
  end

  # <OpenStruct type="custom", recipients="{ \"r\": [\"76561198037177305\"] }", message="{ \"title\": \"Hello\", \"body\": \"World\" }">
  describe "#custom" do
    let(:attributes) do
      {
        type: "custom",
        recipients: recipients,
        message: { title: Faker::Beer.name, body: Faker::Artist.name },
        id: territory.esm_custom_id || territory.id
      }
    end

    it "should send to all" do
      community.update(log_xm8_event: false)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(2)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(2)

      # Check the embeds
      values = attributes[:message].to_ostruct
      embed = ESM::Test.messages.first.second
      expect(embed.title).to eq(values[:title])
      expect(embed.description).to eq(values[:body])

      embed = ESM::Test.messages.second.second
      expect(embed.title).to eq(values[:title])
      expect(embed.description).to eq(values[:body])
    end

    it "should log" do
      community.update(log_xm8_event: true)
      send_notification
      wait_for { ESM::Test.messages.size }.to eq(3)

      # To ensure all messages have been sent
      sleep(1)
      expect(ESM::Test.messages.size).to eq(3)

      # Check the embed
      values = attributes[:message].to_ostruct
      embed = ESM::Test.messages.third.second
      expect(embed.title).to eq("(Delivered) `#{attributes[:type]}` XM8 Notification for `#{server.server_id}`")
      expect(embed.description).to eq("**Title:**\n#{values[:title]}\n**Description:**\n#{values[:body]}")
    end
  end
end
