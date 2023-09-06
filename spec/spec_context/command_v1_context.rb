RSpec.shared_context("command_v1") do
  let!(:community) { ESM::Test.community }
  let!(:user) { ESM::Test.user }
  let(:server) { ESM::Test.server }

  let(:command) { (respond_to?(:command_class) ? command_class : described_class).new }
  let(:second_user) { ESM::Test.user }

  let!(:wsc) { WebsocketClient.new(server) }
  let(:connection) { ESM::Websocket.connections[server.server_id] }

  before do
    wait_for { wsc.connected? }.to be(true)
  end

  after do
    wsc.disconnect!
  end

  def execute!(**opts)
    channel_type = opts.delete(:channel_type) || :text
    send_as_user = opts.delete(:send_as) || user
    command = opts.delete(:command) || self.command

    channel =
      if (channel = opts.delete(:channel))
        channel
      elsif channel_type == :text
        ESM::Test.data[user.guild_type][:channels].sample
      else
        user.discord_user.pm.id
      end

    channel = ESM.bot.channel(channel) unless channel.is_a?(Discordrb::Channel)

    data = {
      id: "", # ID of interaction
      application_id: "", # Bot id?
      type: 2, # Interaction type. 2 is command
      data: {
        id: "", # Command ID
        name: command.command_name # Command name
      },
      guild_id: channel.server&.id, # Server ID
      channel_id: channel.id, # Channel ID
      user: {
        id: send_as_user.discord_id # User ID
      },
      token: ESM.config.token, # Bot token
      version: 1 # IDK
    }

    if command.arguments.size > 0
      options = opts.map do |key, value|
        argument = command.arguments.templates[key]
        raise ArgumentError, "Unable to find argument template for #{key}" if argument.nil?

        {name: argument.display_name.to_s, value: value, type: argument.discord_type}
      end

      data[:data][:options] = [{type: 1, name: command.command_name, options: options}]
    end

    event = Discordrb::Events::ApplicationCommandEvent.new(data.deep_stringify_keys, ESM.bot)
    command.execute(ESM::Event::ApplicationCommand.new(event))
  end
end
