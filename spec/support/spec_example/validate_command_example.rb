RSpec.shared_examples("validate_command") do
  it "has a valid description text" do
    expect(command.description).not_to be_blank
    expect(command.description).not_to match(/todo/i)
  end

  it "has a valid example text" do
    expect(command.example).not_to be_blank
    expect(command.example).not_to match(/todo/i)
  end

  it "has the required defines" do
    defines = command.attributes.to_h
    expect(defines).to have_key(:enabled)
    expect(defines).to have_key(:allowlist_enabled)
    expect(defines).to have_key(:allowlisted_role_ids)
    expect(defines).to have_key(:allowed_in_text_channels)
    expect(defines).to have_key(:cooldown_time)
  end

  it "has valid description text for every argument" do
    command.arguments.each do |name, value|
      argument = command.arguments.templates[name]
      description = argument.description

      expect(description).not_to be_nil, "Argument \"#{name}\" has a nil description"
      expect(description.match?(/^translation missing/i)).to be(false), "Argument \"#{name}\" does not have a valid entry. Ensure `commands.#{command.name}.arguments.#{name}` exists in `config/locales/commands/#{name}/en.yml`"
      expect(description.match?(/todo/i)).to be(false), "Argument \"#{name}\" has a TODO description"
    end
  end
end
