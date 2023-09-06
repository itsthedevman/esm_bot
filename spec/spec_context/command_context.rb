RSpec.shared_context("command") do
  let!(:community) { ESM::Test.community }
  let!(:user) { ESM::Test.user }
  let(:command) { (respond_to?(:command_class) ? command_class : described_class).new }
  let(:server) { ESM::Test.server }
  let(:second_user) { ESM::Test.user }

  #
  # Executes the command as a user in a text or pm channel.
  # The majority of the time, this method will be used along with the input arguments for the command
  #
  # @param channel_type [Symbol] Controls what type of channel messages are triggered in. Options: :text, :pm
  # @param send_as [ESM::User] The user to send the message as. Defaults to the `user` let binding
  # @param command_override [ESM::Command] The command to execute. Defaults to the `command` let binding
  # @param channel [Discordrb::Channel, nil] The channel to execute the command in
  # @param **command_args [Hash] Any arguments the command is expecting as key: value pairs
  #
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

  def wait_for_completion!(event = :on_execute)
    wait_for { command.timers.public_send(event.to_sym).finished? }.to be(true)
  end
end
