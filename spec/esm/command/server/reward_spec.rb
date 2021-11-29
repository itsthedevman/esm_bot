# frozen_string_literal: true

describe ESM::Command::Server::Reward, category: "command" do
  include_examples "command", described_class

  it "is a player command" do
    expect(command.type).to eql(:player)
  end

  it "requires registration" do
    expect(command.registration_required?).to be(true)
  end

  describe "#on_execute/#on_response", requires_connection: true do
    include_examples "connection"

    # reward_items: [],
    # reward_vehicles: [],
    # player_poptabs: 0,
    # locker_poptabs: 0,
    # respect: 0
    it "only has player poptabs" do
      reward = server.server_rewards.default
      reward.update(reward_items: [], reward_vehicles: [], locker_poptabs: 0, respect: 0)

      user.connect
      execute!(channel_type: :pm, server_id: server.server_id)

      # 1: Send the information embed to the user
      message = ESM::Test.messages.shift
      expect(message).not_to be_nil

      information_embed = message.content
      expect(information_embed.description).to eq(command.t("information_embed.description", user: user.mention, server_id: server.server_id, reward_id: "default"))
      expect(information_embed.footer.text).to eq(command.t("information_embed.footer"))
      expect(information_embed.fields.size).to eq(2)

      poptab_field = information_embed.fields.first
      translation_name = "information_embed.fields.player_poptabs"
      expect(poptab_field.name).to eq(command.t("#{translation_name}.name"))
      expect(poptab_field.value).to eq(command.t("#{translation_name}.value", poptabs: reward.player_poptabs.to_poptab))
      expect(poptab_field.inline).to be(true)

      accept_field = information_embed.fields.second
      expect(accept_field.name).to eq(ESM::Embed::EMPTY_SPACE)
      expect(accept_field.value).to eq(command.t("information_embed.fields.accept"))
      expect(accept_field.inline).to be(false)

      # 2: Reply back "accept" and wait for the server to reply
      send_discord_message("accept")

      # 3: Send message to server
      outbound_message = wait_for_outbound_message
      expect(outbound_message.type).to eq("arma")
      expect(outbound_message.data_type).to eq("reward")
      expect(outbound_message.data.player_poptabs).to eq(reward.player_poptabs)
      expect(outbound_message.data.items).to be_nil
      expect(outbound_message.data.locker_poptabs).to be_nil
      expect(outbound_message.data.respect).to be_nil
      expect(outbound_message.data.vehicles).to be_nil

      expect(outbound_message.metadata_type).to eq("command")
      expect(outbound_message.metadata).not_to be_nil

      # 4: Check server response
      inbound_message = wait_for_inbound_message
      expect(inbound_message.type).to eq("arma")
      expect(inbound_message.data_type).to eq("reward")
      expect(inbound_message.data.player_poptabs).to be >= reward.player_poptabs
      expect(inbound_message.data.items).to be_nil
      expect(inbound_message.data.locker_poptabs).to be_nil
      expect(inbound_message.data.respect).to be_nil
      expect(inbound_message.data.vehicles).to be_nil

      expect(inbound_message.metadata_type).to eq("empty")
      expect(inbound_message.metadata).to be_nil

      # 5: Check outbound response
      outbound_message = ESM::Test.messages.shift
      expect(outbound_message).not_to be_nil

      receipt_embed = outbound_message.content
      expect(receipt_embed.title).to eq(command.t("receipt_embed.title"))
      expect(receipt_embed.description).to eq(command.t("receipt_embed.description"))
      expect(receipt_embed.fields.size).to eq(1)

      field = receipt_embed.fields.first
      expect(field.name).to eq(command.t("receipt_embed.fields.player_poptabs.name"))
      expect(field.value).to eq(command.t("receipt_embed.fields.player_poptabs.value", poptabs: reward.player_poptabs.to_poptab))
    end
  end
end
