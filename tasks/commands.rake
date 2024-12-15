# frozen_string_literal: true

namespace :commands do
  task list: :environment do
    ESM::Command.load

    commands = ESM::Command.all.sort_by(&:command_name).each_with_object({}) do |command, hash|
      hash[command.command_name] = command.usage
    end

    puts JSON.pretty_generate(commands)
  end

  task seed_for_communities: :bot do
    ESM::Community.all.each do |community|
      print "  Deleting commands for #{community.community_id}..."
      ESM.bot.get_application_commands(server_id: community.guild_id).each(&:delete)
      puts " done"

      print "  Registering commands for #{community.community_id}..."
      ESM::Command.register_commands(community.guild_id)
      puts " done"
    end
  end

  task seed_for_global: :bot do
    print "  Registering global commands..."
    ESM::Command.register_commands
    puts " done"
  end

  task seed: :bot do
    Rake::Task["delete_global"].invoke
    Rake::Task["seed_for_global"].invoke
  end

  task delete_global: :bot do
    print "Deleting all global commands..."
    ESM.bot.get_application_commands.each(&:delete)
    puts " done"
  end
end
