# frozen_string_literal: true

describe ESM::Event::SendToChannel do
  let(:server) { ESM::Test.server }
  let(:connection) { server.connection }

  before(:each) { wait_for { server.connected? }.to be(true) }

  it "sends a message" do
    inbound_message = ESM::Connection::Message.new(
      type: "event", data_type: "send_to_channel",
      data: { id: ESM::Test.channel.id.to_s, content: Faker::String.random }
    )

    described_class.new(connection, inbound_message).run!

    message = ESM::Test.messages.first
    expect(message).not_to be_nil
    expect(message.content).to eq("*Sent from `#{server.server_id}`*\n#{inbound_message.data.content}")
  end

  it "builds and sends an embed" do
    embed_hash = ESM::Arma::HashMap.new(
      title: Faker::String.random,
      description: Faker::String.random,
      color: ESM::Color.random,
      fields: [
        { name: Faker::String.random, value: Faker::String.random, inline: true }
      ]
    )

    inbound_message = ESM::Connection::Message.new(
      type: "event", data_type: "send_to_channel",
      data: { id: ESM::Test.channel.id.to_s, content: embed_hash.to_json }
    )

    described_class.new(connection, inbound_message).run!

    message = ESM::Test.messages.first
    expect(message).not_to be_nil

    embed = message.content
    expect(embed.title).to eq(embed_hash[:title])
    expect(embed.description).to eq(embed_hash[:description])
    expect(embed.color).to eq(embed_hash[:color])
    expect(embed.fields.size).to eq(1)

    embed_field = embed.fields.first
    hash_field = embed_hash[:fields].first

    expect(embed_field).not_to be_nil
    expect(hash_field).not_to be_nil

    expect(embed_field.name).to eql(hash_field[:name])
    expect(embed_field.value).to eql(hash_field[:value])
    expect(embed_field.inline).to eql(hash_field[:inline])
  end

  it "only allows sending messages to that community's discord channels" do
    inbound_message = ESM::Connection::Message.new(
      type: "event", data_type: "send_to_channel",
      data: { id: "1", content: "" }
    )

    described_class.new(connection, inbound_message).run!

    message = ESM::Test.messages.first
    expect(message).not_to be_nil

    expect(message.content).to match(%r{hi there!\nyour server `#{server.server_id}` has encountered an error that requires your attention. please open `esm.log` located in \[`@esm\/logs\/`\]\(or the pre-configured log file path\) and search for `[\w-]{36}` for the full error.}i)
  end
end
