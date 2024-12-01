# frozen_string_literal: true

describe ESM::Command::Server::Reward, category: "command" do
  include_context "command"
  include_examples "validate_command"

  it "is a player command" do
    expect(command.type).to eq(:player)
  end

  describe "V1" do
    describe "#execute" do
      include_context "connection_v1"

      context "when there are rewards" do
        it "gives them to the player and returns a message" do
          execute!(arguments: {server_id: server.server_id})
          wait_for { ESM::Test.messages.size }.to eq(2)

          embed = ESM::Test.messages.first.content

          # Checks for requestors message
          expect(embed).not_to be_nil

          # Process the request
          request = previous_command.request
          expect(request).not_to be_nil

          # So we can track the response
          ESM::Test.messages.clear

          # Respond to the request
          request.respond(true)

          # Wait for the server to respond
          wait_for { connection.requests }.to be_blank
          wait_for { ESM::Test.messages.size }.to eq(1)

          embed = ESM::Test.messages.first.content
          reward = server.server_reward

          expect(embed.description).to include("#{reward.player_poptabs}x Poptabs (Player)") if reward.player_poptabs.positive?
          expect(embed.description).to include("#{reward.locker_poptabs}x Poptabs (Locker)") if reward.locker_poptabs.positive?
          expect(embed.description).to include("#{reward.respect}x Respect") if reward.respect.positive?

          reward.reward_items.each do |item, quantity|
            # Technically, the item should be converted to a proper display name by the server, but I don't have that ability here.
            expect(embed.description).to include("#{quantity}x #{item}")
          end
        end
      end

      context "when the user already has a request" do
        it "raises an exception" do
          execution_args = {arguments: {server_id: server.server_id}}

          # Create a pending request
          create(
            :request,
            requestor: user,
            requestee: user,
            requested_from_channel_id: ESM::Test.channel(in: community).id,
            command_name: command.command_name,
            command_arguments: execution_args[:arguments]
          )

          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
            embed = error.data
            expect(embed.description).to match(/it appears you already have a request pending/i)
          end
        end
      end

      context "when there are no rewards configured" do
        it "raises an exception" do
          # Remove the default reward and create a blank one
          server.server_reward.delete
          server.send(:create_default_reward)

          execution_args = {arguments: {server_id: server.server_id}}
          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
            embed = error.data
            expect(embed.description).to match(/the selected reward package is not available at this tim/i)
          end
        end
      end
    end
  end

  describe "V2", v2: true do
    describe "#on_execute", requires_connection: true do
      include_context "connection"

      subject(:execute_command) { execute!(arguments: {server_id: server.server_id}) }

      before do
        spawn_player_for(user)
      end

      context "when there are rewards" do
        let!(:reward_items) do
          {Exile_Weapon_AKM: 1, Exile_Magazine_30Rnd_762x39_AK: 3}
        end

        let!(:player_poptabs) { 10 }
        let!(:locker_poptabs) { 20 }
        let!(:respect) { 30 }

        before do
          server.server_reward.update!(
            reward_items:,
            player_poptabs:,
            locker_poptabs:,
            respect:
          )
        end

        it "gifts them to the player" do
          execute_command

          wait_for { ESM::Test.messages.size }.to eq(2)
          accept_request
          wait_for { ESM::Test.messages.size }.to eq(3)

          embed = latest_message
          expect(embed).not_to be(nil)
          binding.pry
        end
      end

      context "when there are no rewards" do
        before do
          server.server_reward.update!(
            reward_items: [],
            player_poptabs: 0,
            locker_poptabs: 0,
            respect: 0
          )
        end

        include_examples "raises_check_failure" do
          let!(:matcher) { "the selected reward package is not available at this time" }
        end
      end

      context "when there is an existing request" do
        before do
          # Executing the command but not handling the request will cause the request to be pending
          execute!(arguments: {server_id: server.server_id})
          previous_command.current_cooldown.reset!
        end

        include_examples "raises_check_failure" do
          let!(:matcher) { "it appears you already have a request pending" }
        end
      end
    end
  end
end
