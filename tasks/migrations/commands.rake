namespace :commands do
  task register_commands_for_development: :bot do
    return unless ESM.env.development?

    commands = ESM::Command.by_namespace_for_global.deep_merge(ESM::Command.by_namespace_for_server)

    ESM::Community.all.pluck(:guild_id).each do |community_discord_id|
      commands.each do |name, segments_or_command|
        ESM::Command.register_command(name, segments_or_command, community_discord_id)
      end
    end
  end

  task register_global_commands: :bot do
    ESM::Command.register_global_commands
  end
end
