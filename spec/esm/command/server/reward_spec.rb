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
    include_context "connection"

    # reward_items: [],
    # reward_vehicles: [],
    # player_poptabs: 0,
    # locker_poptabs: 0,
    # respect: 0
    it "only has player poptabs" do
      reward = server.server_rewards.default
      reward.update(reward_items: [], reward_vehicles: [], locker_poptabs: 0, respect: 0)

      execute!(server_id: server.server_id)

      # 1: Send the information embed to the user
      message = ESM::Test.messages.first
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
      ######

      # 2: Reply back "accept" and wait for the server to reply
      send_discord_message("accept")
      outbound_message = nil
      wait_until { outbound_message = ESM::Test.server_messages.first }
      binding.pry
      ######

      # 3: Send message to server
      # 4: Handle server response
    end
  end
end
