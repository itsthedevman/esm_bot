# frozen_string_literal: true

#############################
# Must be ran before autoload
#############################
I18n.load_path += Dir[File.expand_path("config/locales/**/*.yml")]
I18n.reload!

ESM.initialize_logger
ESM.initialize_steam
ESM.initialize_redis

#############################
# DB migrations
#############################
module Rails
  def self.root
    Dir.pwd
  end
end

#############################
# Autoload ESM
#############################
ESM.loader.tap do |loader|
  loader.inflector.inflect(
    "esm" => "ESM",
    "ostruct" => "OpenStruct",
    "xm8" => "XM8",
    "api" => "API",
    "json" => "JSON"
  )

  # Convert ESM::Model::Server -> ESM::Server
  loader.collapse(ESM.root.join("lib", "esm", "model"))

  # Forces the jobs to be loaded on the Root path
  # ESM::Jobs::SomeJob -> SomeJob
  loader.push_dir(ESM.root.join("lib", "esm", "jobs"))

  # Don't load extensions, we do that above
  loader.ignore(ESM.root.join("lib", "esm", "extension"))

  # Ignore inits
  loader.ignore(ESM.root.join("lib", "esm", "database.rb"))
  loader.ignore(ESM.root.join("lib", "post_init.rb"))
  loader.ignore(ESM.root.join("lib", "pre_init.rb"))
  loader.ignore(ESM.root.join("lib", "pre_init_dev.rb"))

  # gemspec expects this file, but Zeitwerk does not like it
  loader.ignore(ESM.root.join("lib", "esm", "version.rb"))
  loader.ignore(ESM.root.join("lib", "esm", "esm.rb"))
end

#############################
# Configure Inflector
#############################
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym("ESM")
  inflect.acronym("ID")
  inflect.acronym("UID")
end
