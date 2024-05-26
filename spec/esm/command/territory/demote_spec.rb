# frozen_string_literal: true

describe ESM::Command::Territory::Demote, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    let(:territory_id) { Faker::Alphanumeric.alphanumeric(number: 3..30) }

    context "when the command is executed correctly" do
      it "demotes the target user" do
        request = execute!(
          arguments: {
            server_id: server.server_id,
            territory_id: territory_id,
            target: second_user.mention
          }
        )

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(
          /hey #{user.mention}, `#{second_user.steam_uid}` has been demoted to builder in territory `#{territory_id}` on `#{server.server_id}`/i
        )
      end
    end

    context "when the target is an unregistered user" do
      it "raise an exception" do
        second_user.update(steam_uid: "")

        execution_args = {
          arguments: {
            server_id: server.server_id,
            territory_id: territory_id,
            target: second_user.mention
          }
        }

        expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure) do |error|
          embed = error.data
          expect(embed.description).to match(/has not registered with me yet/i)
        end
      end
    end

    context "when the target is an unregistered steam uid" do
      it "demotes the user" do
        steam_uid = second_user.steam_uid
        second_user.update(steam_uid: "")

        request = execute!(
          arguments: {
            server_id: server.server_id,
            territory_id: territory_id,
            target: steam_uid
          }
        )

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(
          /hey #{user.mention}, `#{steam_uid}` has been demoted to builder in territory `#{territory_id}` on `#{server.server_id}`/i
        )
      end
    end
  end

  describe "V2", category: "command" do
    include_context "command", described_class
    include_examples "validate_command"

    it "is a player command" do
      expect(command.type).to eq(:player)
    end

    it "requires registration" do
      expect(command.registration_required?).to be(true)
    end

    describe "#on_execute", requires_connection: true do
      include_context "connection"

      let!(:territory) do
        owner_uid = ESM::Test.steam_uid
        create(
          :exile_territory,
          owner_uid: owner_uid,
          moderators: [owner_uid],
          build_rights: [owner_uid],
          server_id: server.id
        )
      end

      before do
        user.create_account
        second_user.create_account

        territory.create_flag
      end

      context "when the player is a moderator and the target is another moderator" do
        before do
          # I rarely use this syntax, but it felt fun
          territory.moderators << user.steam_uid << second_user.steam_uid
          territory.build_rights << user.steam_uid << second_user.steam_uid
          territory.save!
        end

        it "demotes the target to builder" do
          execute!(
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: second_user.steam_uid
            }
          )

          territory.reload

          expect(territory.moderators).not_to include(second_user.steam_uid)
          expect(territory.build_rights).to include(second_user.steam_uid)
        end
      end

      context "when the player is a territory admin and the target is a moderator" do
        before do
          make_territory_admin!(user)

          territory.moderators << second_user.steam_uid
          territory.build_rights << second_user.steam_uid
          territory.save!
        end

        it "demotes the target" do
          execute!(
            arguments: {
              server_id: server.server_id,
              territory_id: territory.encoded_id,
              target: second_user.steam_uid
            }
          )

          territory.reload

          expect(territory.moderators).not_to include(second_user.steam_uid)
          expect(territory.build_rights).to include(second_user.steam_uid)
        end
      end

      context "when the territory flag is null" do
        before { territory.delete_flag }

        it "raises NullFlag" do
          expectation = expect do
            execute!(
              arguments: {
                server_id: server.server_id,
                territory_id: territory.encoded_id,
                target: second_user.steam_uid
              }
            )
          end

          expectation.to raise_error(ESM::Exception::ExtensionError) do |error|
            expect(error.data.description).to eq("")
          end
        end
      end

      context "when the player has not joined the server"
      context "when the player does not have permission"
      context "when the target is the owner"
      context "when the target is a builder"
      context "when the target is not a member"
    end
  end
end
