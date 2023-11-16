# frozen_string_literal: true

describe ESM::Command::Server::Territories, category: "command" do
  include_context "command"
  include_examples "validate_command"

  describe "#execute" do
    include_context "connection_v1"

    before do
      # IMPORTANT!
      # If we don't reload the server model after WSC connection, the server settings will be wrong!
      server.reload
    end

    context "when the player has territories" do
      it "returns their territories" do
        request = execute!(channel_type: :dm, arguments: {server_id: server.server_id})

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(response.size)

        ESM::Test.messages.map(&:content).each_with_index do |embed, index|
          territory = ESM::Exile::Territory.new(server: server, territory: response[index])

          expect(embed.title).to eq("Territory \"#{territory.name}\"")
          expect(embed.thumbnail.url).to eq(territory.flag_path)
          expect(embed.color).to eq(territory.status_color)
          expect(embed.description).to eq(territory.payment_reminder_message)

          field_info = [
            {name: "Territory ID", value: "```#{territory.id}```"},
            {name: "Flag Status", value: "```#{territory.flag_status}```"},
            {name: "Next Due Date", value: "```#{territory.next_due_date.strftime(ESM::Time::Format::TIME)}```"},
            {name: "Last Paid", value: "```#{territory.last_paid_at.strftime(ESM::Time::Format::TIME)}```"},
            {name: "Price to renew protection", value: territory.renew_price},
            {value: "__Current Territory Stats__"},
            {name: "Level", value: territory.level},
            {name: "Radius", value: "#{territory.radius}m"},
            {name: "Current / Max Objects", value: "#{territory.object_count}/#{territory.max_object_count}"}
          ]

          if territory.upgradeable?
            field_info.push(
              {value: "__Next Territory Stats__"},
              {name: "Level", value: territory.upgrade_level},
              {name: "Radius", value: "#{territory.upgrade_radius}m"},
              {name: "Max Objects", value: territory.upgrade_object_count},
              {name: "Price", value: territory.upgrade_price}
            )
          end

          field_info.push({value: "__Territory Members__"}, {name: "Owner", value: territory.owner})

          # Now check the fields
          # Removing them from the embed so we can check moderators/builders easily
          field_info.each do |field|
            embed_field = embed.fields.shift
            expect(embed_field.name).to eq(field[:name].to_s) if field[:name].present?
            expect(embed_field.value).to eq(field[:value].to_s)
          end

          moderator_fields = ESM::Embed.new
            .add_field(value: territory.moderators)
            .fields
            .map(&:value)

          moderator_fields.each_with_index do |moderator_field, index|
            field = embed.fields.shift

            if index.zero?
              expect(field.name).to match(/moderator/i)
            else
              expect(field.name).to eq(ESM::Embed::EMPTY_SPACE)
            end

            expect(field.value).to eq(moderator_field)
          end

          builder_fields = ESM::Embed.new
            .add_field(value: territory.builders)
            .fields
            .map(&:value)

          builder_fields.each_with_index do |builder_field, index|
            field = embed.fields.shift

            if index.zero?
              expect(field.name).to match(/build rights/i)
            else
              expect(field.name).to eq(ESM::Embed::EMPTY_SPACE)
            end

            expect(field.value).to eq(builder_field)
          end
        end
      end
    end

    context "when the player does not have territories" do
      it "returns an error message" do
        wsc.flags.RETURN_NO_TERRITORIES = true

        request = execute!(channel_type: :dm, arguments: {server_id: server.server_id})

        expect(request).not_to be_nil
        wait_for { connection.requests }.to be_blank
        wait_for { ESM::Test.messages.size }.to eq(1)

        embed = ESM::Test.messages.first.content
        expect(embed.description).to match(/unable to find any territories/i)
        expect(embed.color).to eq(ESM::Color::Toast::RED)
      end
    end
  end
end
