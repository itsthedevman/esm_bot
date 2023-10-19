# frozen_string_literal: true

describe ESM::Command do
  subject(:commands) { described_class }

  context "when ESM has commands" do
    it do
      expect(commands.all).not_to be_empty
    end

    it "is organized by type" do
      expect(commands.by_type[:player]).not_to be_empty
      expect(commands.by_type[:admin]).not_to be_empty
    end

    it "organized by namespace" do
      expect(commands.by_namespace).to match(
        a_hash_including(
          territory: a_hash_including(
            :upgrade, :list, :set_id, :remove_player, :promote_player,
            :pay, :demote_player, :add_player, :admin
          ),
          server: a_hash_including(
            :uptime, :stuck, :details, :reward, :my_player, :gamble, :admin
          ),
          request: a_hash_including(:list, :decline, :accept),
          pictures: a_hash_including(:snek, :meow, :doggo, :birb),
          my: a_hash_including(:steam_uid, :preferences),
          register: be < ESM::ApplicationCommand,
          help: be < ESM::ApplicationCommand,
          community: a_hash_including(:servers, :id, :admin)
        )
      )
    end
  end

  describe ".[]" do
    context "when the input is a 'OG command name'" do
      it do
        expect(commands["help"]).to be(ESM::Command::General::Help)
      end
    end

    context "when the input is a 'slash command'" do
      it do
        expect(commands["/community servers"]).to be(ESM::Command::Community::Servers)
      end
    end

    context "when the input is a 'slash command' without a slash" do
      it do
        expect(commands["server my_player"]).to be(ESM::Command::Server::Me)
      end
    end

    context "when the input is the end of a 'slash command'" do
      it do
        expect(commands["promote_player"]).to be(ESM::Command::Territory::Promote)
      end
    end

    context "when the input is invalid" do
      it do
        expect(commands["this command cannot exist"]).to be(nil)
      end
    end
  end

  describe ".get" do
    it "is aliased correctly" do
      expect(commands.get("birb")).to be(ESM::Command::Pictures::Birb)
    end
  end

  describe ".include?" do
    context "when the command exists" do
      it do
        expect(commands.include?("help")).to be(true)
      end
    end

    context "when the command does not exist" do
      it do
        expect(commands.include?("This command cannot exist")).to be(false)
      end
    end
  end
end
