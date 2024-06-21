# frozen_string_literal: true

describe ESM::Command::Territory::Demote, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "V1" do
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
          moderators: [owner_uid, user.steam_uid, second_user.steam_uid],
          build_rights: [owner_uid, user.steam_uid, second_user.steam_uid],
          server_id: server.id
        )
      end

      before do
        user.exile_account
        second_user.exile_account

        territory.create_flag
      end

      subject(:execute_command) do
        execute!(
          arguments: {
            server_id: server.server_id,
            territory_id: territory.encoded_id,
            target: second_user.steam_uid
          }
        )
      end

      shared_examples "successful_demotion" do
        it "demotes the target" do
          execute_command
          territory.reload

          expect(territory.moderators).not_to include(second_user.steam_uid)
          expect(territory.build_rights).to include(second_user.steam_uid)
        end
      end

      context "when the player is a moderator and the target is another moderator" do
        include_examples "successful_demotion"
      end

      context "when the player is a territory admin and the target is a moderator" do
        before do
          make_territory_admin!(user)
          territory.revoke_membership(user.steam_uid)
        end

        include_examples "successful_demotion"
      end

      context "when the territory flag is null" do
        before { territory.delete_flag }

        include_examples "arma_error_null_flag"
      end

      context "when the player has not joined the server" do
        before { user.exile_account.destroy! }

        include_examples "arma_error_player_needs_to_join"
      end

      context "when the target has not joined the server" do
        before { second_user.exile_account.destroy! }

        include_examples "arma_error_target_needs_to_join"
      end

      context "when the player is not a moderator" do
        before do
          territory.revoke_membership(user.steam_uid)
        end

        include_examples "arma_error_missing_territory_access"
      end

      context "when the target is the owner" do
        before do
          territory.update!(owner_uid: second_user.steam_uid)
        end

        it "raises Demote_CannotDemoteOwner" do
          expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
            expect(error.data.description).to match("you have no power here")
          end
        end
      end

      context "when the target is a builder" do
        before do
          territory.moderators.delete(second_user.steam_uid)
          territory.save!
        end

        it "raises Demote_CannotDemoteBuilder" do
          expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
            expect(error.data.description).to match("you cannot demote someone who is already at the lowest rank")
          end
        end
      end

      context "when the target is not a member" do
        before do
          territory.revoke_membership(second_user.steam_uid)
        end

        it "raises Demote_CannotDemoteNothing" do
          expect { execute_command }.to raise_error(ESM::Exception::ExtensionError) do |error|
            expect(error.data.description).to match("you can't demote someone you have no power over")
          end
        end
      end
    end
  end
end
