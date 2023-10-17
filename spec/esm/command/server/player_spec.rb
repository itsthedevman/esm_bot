# frozen_string_literal: true

describe ESM::Command::Server::Player, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    before do
      grant_command_access!(community, "player")
    end

    describe "Money" do
      def check!
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)
        embed = ESM::Test.messages.first.second

        expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s money by #{response.modified_amount.to_readable} poptabs. They used to have #{response.previous_amount.to_readable} poptabs, they now have #{response.new_amount.to_readable}.")
      end

      context "when the type is 'money'" do
        it "modifies the player's money" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "money",
              amount: Faker::Number.between(from: -500, to: 500)
            }
          )

          check!
        end

        it "requires an amount" do
          execution_args = {
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "money"
            }
          }

          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure)
        end
      end

      context "when the type is the shorthand 'm'" do
        it "modifies the player's money" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "money",
              amount: Faker::Number.between(from: -500, to: 500)
            }
          )

          check!
        end
      end
    end

    describe "Locker" do
      def check!
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)
        embed = ESM::Test.messages.first.second

        expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s locker by #{response.modified_amount.to_readable} poptabs. They used to have #{response.previous_amount.to_readable} poptabs, they now have #{response.new_amount.to_readable}.")
      end

      context "when the type is 'locker'" do
        it "modifies the player's locker" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "locker",
              amount: Faker::Number.between(from: -500, to: 500)
            }
          )

          check!
        end

        it "requires an amount" do
          execution_args = {
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "locker"
            }
          }

          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure)
        end
      end

      context "when the type is the shorthand 'l'" do
        it "modifies the player's locker" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "l",
              amount: Faker::Number.between(from: -500, to: 500)
            }
          )

          check!
        end
      end
    end

    describe "Respect" do
      def check!
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)
        embed = ESM::Test.messages.first.second

        expect(embed.description).to eq("#{user.mention}, you've modified `#{second_user.steam_uid}`'s respect by #{response.modified_amount.to_readable} points. They used to have #{response.previous_amount.to_readable}, they now have #{response.new_amount.to_readable}.")
      end

      context "when the type is 'respect'" do
        it "modifies the player's respect" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "respect",
              amount: Faker::Number.between(from: -500, to: 500)
            }
          )

          check!
        end

        it "requires an amount" do
          execution_args = {
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "respect"
            }
          }

          expect { execute!(**execution_args) }.to raise_error(ESM::Exception::CheckFailure)
        end
      end

      context "when the type is the shorthand 'r'" do
        it "modifies the player's respect" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "r",
              amount: Faker::Number.between(from: -500, to: 500)
            }
          )

          check!
        end
      end
    end

    describe "Heal" do
      def check!
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)
        embed = ESM::Test.messages.first.second

        expect(embed.description).not_to be_blank
      end

      context "when the type is 'heal'" do
        it "heals the player" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "heal"
            }
          )

          check!
        end

        it "will ignore the amount argument" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "h",
              amount: 55
            }
          )

          expect(previous_command.arguments.amount).to be_nil
        end
      end

      context "when the type is the shorthand 'h'" do
        it "heals the player" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "h"
            }
          )

          check!
        end
      end
    end

    describe "Kill" do
      def check!
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)
        embed = ESM::Test.messages.first.second

        expect(embed.description).not_to be_blank
      end

      context "when the type is 'kill'" do
        it "kills the player" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "kill"
            }
          )

          check!
        end

        it "will ignore the amount argument" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "k",
              amount: 55
            }
          )

          expect(previous_command.arguments.amount).to be_nil
        end
      end

      context "when the type is the shorthand 'k'" do
        it "kills the player" do
          execute!(
            arguments: {
              server_id: server.server_id,
              target: second_user.mention,
              action: "k"
            }
          )

          check!
        end
      end
    end

    context "when the target is a non-registered steam uid" do
      it "works as expected" do
        steam_uid = second_user.steam_uid
        second_user.update(steam_uid: "")

        execute!(
          arguments: {server_id: server.server_id, target: steam_uid, action: "h"}
        )

        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)
        embed = ESM::Test.messages.first.second

        expect(embed.description).not_to be_blank
      end
    end
  end
end
