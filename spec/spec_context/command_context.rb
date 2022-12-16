RSpec.shared_context("command") do
  let!(:command) { (respond_to?(:command_class) ? command_class : described_class).new }
  let(:community) { ESM::Test.community }
  let(:server) { ESM::Test.server }
  let(:user) { ESM::Test.user }

  #
  # Executes the command as a user in a text or pm channel.
  # The majority of the time, this method will be used along with the input arguments for the command
  #
  # @param fail_on_raise [Boolean] Controls if the spec will fail if the execute raises an exception. Default: true
  # @param channel_type [Symbol] Controls what type of channel messages are triggered in. Options: :text, :pm
  # @param send_as [ESM::User] The user to send the message as. Defaults to the `user` let binding
  # @param command_override [ESM::Command] The command to execute. Defaults to the `command` let binding
  # @param **command_args [Hash] Any arguments the command is expecting as key: value pairs
  #
  def execute!(fail_on_raise: true, channel_type: :text, send_as: user, command: self.command, **command_args)
    command_statement = command.statement(command_args)
    event = CommandEvent.create(command_statement, user: send_as, channel_type: channel_type)

    if fail_on_raise
      result = nil
      expect { result = command.execute(event) }.not_to raise_error
      result
    else
      command.execute(event)
    end
  end
end
