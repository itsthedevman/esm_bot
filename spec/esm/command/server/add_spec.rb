# frozen_string_literal: true

describe ESM::Command::Server::Add, category: "command" do
  let!(:command) { ESM::Command::Server::Add.new }

  describe "V1" do
    it "should be valid" do
      expect(command).not_to be_nil
    end

    it "should have 3 argument" do
      expect(command.arguments.size).to eq(3)
    end

    it "should have a description" do
      expect(command.description).not_to be_blank
    end

    it "should have examples" do
      expect(command.example).not_to be_blank
    end

    describe "#execute" do
      let!(:community) { ESM::Test.community }
      let!(:server) { ESM::Test.server }
      let!(:user) { ESM::Test.user }
      let(:second_user) { ESM::Test.user }
      let!(:wsc) { WebsocketClient.new(server) }
      let(:connection) { ESM::Websocket.connections[server.server_id] }
      let(:response) { command.response }

      before :each do
        wait_for { wsc.connected? }.to be(true)
      end

      after :each do
        wsc.disconnect!
      end

      it "should not allow an unregistered user" do
        second_user.update(steam_uid: nil)
        command_statement = command.statement(
          server_id: server.server_id,
          territory_id: Faker::Crypto.md5[0, 5],
          target: second_user.mention
        )

        event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

        expect { command.execute(event) }.to raise_error(ESM::Exception::CheckFailure) do |error|
          embed = error.data
          expect(embed.description).to match(/has not registered with me yet. tell them to head over/i)
        end
      end

      it "should add (Different user)" do
        command_statement = command.statement(
          server_id: server.server_id,
          territory_id: Faker::Crypto.md5[0, 5],
          target: second_user.mention
        )

        event = CommandEvent.create(command_statement, user: user, channel_type: :dm)
        expect { command.execute(event) }.not_to raise_error

        embed = ESM::Test.messages.first.second

        # Checks for requestors message
        expect(embed).not_to be_nil

        # Checks for requestees message
        expect(ESM::Test.messages.size).to eq(2)

        # Process the request
        request = command.request
        expect(request).not_to be_nil

        # Respond to the request
        request.respond(true)

        # Reset so we can track the response
        ESM::Test.messages.clear

        # Wait for the server to respond
        wait_for { connection.requests }.to be_blank

        expect(ESM::Test.messages.size).to eq(2)
      end

      it "should add (Same user / Territory Admin)" do
        command_statement = command.statement(server_id: server.server_id, territory_id: Faker::Crypto.md5[0, 5], target: user.mention)
        event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

        expect { command.execute(event) }.not_to raise_error
        expect(ESM::Test.messages.size).to eq(0)

        # We don't create a request for this
        expect(ESM::Request.all.size).to eq(0)

        # Reset so we can track the response
        ESM::Test.messages.clear

        # Wait for the server to respond
        wait_for { connection.requests }.to be_blank

        expect(ESM::Test.messages.size).to eq(1)
      end

      it "should not allow adding by non-registered steam uid" do
        steam_uid = second_user.steam_uid
        second_user.update(steam_uid: "")

        command_statement = command.statement(server_id: server.server_id, territory_id: Faker::Crypto.md5[0, 5], target: steam_uid)
        event = CommandEvent.create(command_statement, user: user, channel_type: :dm)

        expect { command.execute(event) }.to raise_error do |error|
          expect(error.data.description).to match(/hey .+, .+ has not registered with me yet/i)
        end
      end
    end
  end

  describe "V2", category: "command", v2: true do
    include_context "command"
    include_examples "validate_command"

    it "is an player command" do
      expect(command.type).to eql(:player)
    end

    it "requires registration" do
      expect(command.registration_required?).to be(true)
    end

    # Change "requires_connection" to true if this command requires the client to be connected
    describe "#on_execute/#on_response", requires_connection: true do
      include_context "connection"

      let(:territory) do
        owner_uid = ESM::Test.steam_uid
        create(
          :exile_territory,
          owner_uid: owner_uid,
          moderators: [owner_uid, user.steam_uid],
          build_rights: [owner_uid, user.steam_uid],
          server_id: server.id
        )
      end

      it "adds the user and logs to Discord" do
        execute!(server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid)
        wait_for { ESM::Test.messages }.not_to be_empty

        # Checks for requestors message
        message = ESM::Test.messages.first
        expect(message).not_to be_nil

        # Checks for requestees message
        expect(ESM::Test.messages.size).to eq(2)

        # Process the request
        request = command.request
        expect(request).not_to be_nil

        # Respond to the request
        request.respond(true)

        # 1: Request
        # 2: Request notice
        # 3: Target's add notification
        # 4: Requestor's confirmation
        # 5: Discord log
        wait_for { ESM::Test.messages.size }.to eq(5)

        # The last messages are not always in order...
        expect(
          ESM::Test.messages.find(/you've been added to `#{territory.encoded_id}` successfully/i)
        ).not_to be_nil

        expect(
          ESM::Test.messages.find(
            /#{second_user.distinct} has been added to territory `#{territory.encoded_id}`/
          )
        ).not_to be_nil

        # Admin log on the community's discord server
        log_message = ESM::Test.messages.find("Player added Target to territory")
        expect(log_message).not_to be_nil
        expect(log_message.destination.id.to_s).to eq(community.logging_channel_id)

        log_embed = log_message.content
        expect(log_embed.fields.size).to eq(3)

        [
          {
            name: "Territory",
            value: "ID: #{territory.encoded_id}\nName: #{territory.name}"
          },
          {
            name: "Player",
            value: "Discord ID: #{user.discord_id}\nSteam UID: #{user.steam_uid}\nDiscord name: #{user.discord_username}\nDiscord mention: #{user.mention}"
          },
          {
            name: "Target",
            value: "Discord ID: #{second_user.discord_id}\nSteam UID: #{second_user.steam_uid}\nDiscord name: #{second_user.discord_username}\nDiscord mention: #{second_user.mention}"
          }
        ].each_with_index do |test_field, i|
          field = log_embed.fields[i]
          expect(field).not_to be_nil
          expect(field.name).to eq(test_field[:name])
          expect(field.value).to eq(test_field[:value])
        end

        # Check that Arma update the territory
        territory.reload
        expect(territory.build_rights).to include(second_user.steam_uid)
      end

      it "adds a user via territory admin override", :territory_admin_bypass do
        # The user and target user are not members of this territory.
        # However, user is a territory admin
        territory.revoke_membership(user.steam_uid)

        execute!(server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid)
        wait_for { ESM::Test.messages.size }.to eq(2)

        # 1: Request
        # 2: Request notice
        # 3: Target's add notification
        # 4: Requestor's confirmation
        # 5: Discord log
        expect(command.request&.respond(true)).to be_truthy
        wait_for { ESM::Test.messages.size }.to eq(5)

        expect(
          ESM::Test.messages.find(/you've been added to `#{territory.encoded_id}` successfully/i)
        ).not_to be_nil
      end

      it "adds self via territory admin override", :territory_admin_bypass do
        # The user and target user are not members of this territory.
        # However, user is a territory admin
        territory.revoke_membership(user.steam_uid)

        execute!(server_id: server.server_id, territory_id: territory.encoded_id, target: user.steam_uid)

        # No request message is sent for oneself
        # 1: Success message
        # 2: Discord log
        wait_for { ESM::Test.messages.size }.to eq(2)

        expect(
          ESM::Test.messages.find(/you've been added to `#{territory.encoded_id}` successfully/i)
        ).not_to be_nil
      end

      it "does not allow adding a Steam UID that hasn't been registered with ESM" do
        second_user_steam_uid = second_user.steam_uid
        second_user.update(steam_uid: "")

        expect {
          execute!(
            server_id: server.server_id,
            territory_id: territory.encoded_id,
            target: second_user_steam_uid,
            fail_on_raise: false
          )
        }.to raise_error do |error|
          expect(error.data.description).to match(/hey .+, .+ has not registered with me yet/i)
        end
      end

      describe "SQF Errors" do
        before :context do
          disable_log_printing
        end

        after :context do
          enable_log_printing
        end

        it "handles NullFlag" do
          territory.delete_flag

          execute!(server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid)
          wait_for { ESM::Test.messages.size }.to eq(2)

          # 1: Request
          # 2: Request notice
          # 3: Discord log
          # 4: Failure notification
          expect(command.request&.respond(true)).to be_truthy
          wait_for { ESM::Test.messages.size }.to eq(4)

          expect(
            ESM::Test.messages.find(
              "Player attempted to add Target to territory, but the territory flag was not found in game"
            )
          ).not_to be_nil

          expect(
            ESM::Test.messages.find(/i was unable to find a territory with the ID of `#{territory.encoded_id}`/i)
          ).not_to be_nil
        end

        it "handles MissingAccess" do
          territory.revoke_membership(user.steam_uid)

          execute!(server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid)
          wait_for { ESM::Test.messages.size }.to eq(2)

          # 1: Request
          # 2: Request notice
          # 3: Discord log
          # 4: Failure notification
          expect(command.request&.respond(true)).to be_truthy
          wait_for { ESM::Test.messages.size }.to eq(4)

          expect(
            ESM::Test.messages.find("Player attempted to add Target to territory, but Player does not have permission")
          ).not_to be_nil

          expect(
            ESM::Test.messages.find(
              "#{user.mention}, you do not have permission to add people to `#{territory.encoded_id}`"
            )
          ).not_to be_nil
        end

        it "handles InvalidAdd" do
          execute!(server_id: server.server_id, territory_id: territory.encoded_id, target: user.steam_uid)

          # No request message is sent for oneself
          # 1: Player failure message
          # 2: Discord log
          wait_for { ESM::Test.messages.size }.to eq(2)

          expect(
            ESM::Test.messages.find("#{user.mention}, you cannot add yourself to this territory")
          ).not_to be_nil

          expect(
            ESM::Test.messages.find("Player attempted to add themselves to the territory. Time to go laugh at them!")
          ).not_to be_nil
        end

        it "handles InvalidAdd_Owner" do
          territory.owner_uid = second_user.steam_uid
          territory.save!

          execute!(server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid)
          wait_for { ESM::Test.messages.size }.to eq(2)

          # 1: Request
          # 2: Request notice
          # 3: Player only Discord message
          expect(command.request&.respond(true)).to be_truthy
          wait_for { ESM::Test.messages.size }.to eq(3)

          expect(
            ESM::Test.messages.find(
              "#{user.mention}, the Target is the owner of this territory which automatically makes them a member of this territory, silly :stuck_out_tongue_winking_eye:"
            )
          ).not_to be_nil
        end

        it "handles InvalidAdd_Exists" do
          territory.build_rights << second_user.steam_uid
          territory.save!

          execute!(server_id: server.server_id, territory_id: territory.encoded_id, target: second_user.steam_uid)
          wait_for { ESM::Test.messages.size }.to eq(2)

          # 1: Request
          # 2: Request notice
          # 3: Player only Discord message
          expect(command.request&.respond(true)).to be_truthy
          wait_for { ESM::Test.messages.size }.to eq(3)

          expect(
            ESM::Test.messages.find("#{user.mention}, this Player already has build rights")
          ).not_to be_nil
        end
      end
    end
  end
end
