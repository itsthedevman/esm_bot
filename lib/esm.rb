# frozen_string_literal: true

# Welcome to Exile Server Manager!
#   I hope you enjoy your stay.
#
# Just fyi, this file is laid out in a particular order so
#   I can access ESM.env and ESM.config when all other files load

[
  # This contains a check for the existence of the Rails class.
  # One of the action/active gems defines Rails, so this needs to be loaded first
  "sucker_punch",

  "action_view",
  "action_view/helpers",
  "active_record",
  "active_support",
  "active_support/all",
  "activerecord-import",
  "base64",
  "discordrb",
  "dotenv",
  "dotiw",
  "eventmachine",
  "fast_jsonparser",
  "faye/websocket",
  "hashids",
  "httparty",
  "i18n",
  "puma",
  "puma/events",
  "redis",
  "securerandom",
  "semantic",
  "sinatra/base",
  "steam_web_api",
  "steam-condenser",
  "terminal-table",
  "yaml",
  "zeitwerk"
].each { |gem| require gem }

require "otr-activerecord" if ENV["ESM_ENV"] != "production"

# Load Dotenv variables; overwriting any that already exist
Dotenv.overload
Dotenv.overload(".env.test") if ENV["ESM_ENV"] == "test"
Dotenv.overload(".env.prod") if ENV["ESM_ENV"] == "production"

module ESM
  REDIS_OPTS = {
    reconnect_attempts: 10,
    reconnect_delay: 1.5,
    reconnect_delay_max: 10.0
  }.freeze

  class << self
    attr_reader :bot, :config, :logger, :env, :redis
  end

  def self.run!
    # Cache the A3 lookup data
    ESM::Arma::ClassLookup.cache

    load_i18n
    initialize_steam
    initialize_logger
    initialize_redis

    # Subscribe to notifications
    ESM::Notifications.subscribe

    # Start the bot
    @bot = ESM::Bot.new

    if ESM.env.test? || @console
      # Allow RSpec to continue
      Thread.new { @bot.run }
    else
      @bot.run
    end
  end

  def self.root
    @root ||= Pathname.new(File.expand_path("."))
  end

  # Allow IRB to be not-blocked by ESM's main thread
  def self.console!
    @console = true
  end

  def self.load_i18n
    I18n.load_path += Dir[File.expand_path("config/locales/**/*.yml")]
    I18n.reload!
  end

  def self.initialize_steam
    SteamWebApi.configure do |config|
      config.api_key = @config.steam_api_key
    end
  end

  def self.initialize_logger
    @logger = Logger.new("log/#{env}.log", "daily")

    @logger.formatter = proc do |severity, datetime, progname = "N/A", msg|
      header = "#{severity} [#{datetime.strftime("%F %H:%M:%S:%L")}] (#{progname})"
      body = "\n\t#{msg.to_s.gsub("\n", "\n\t")}\n\n"

      if ENV["PRINT_LOG"] == "true"
        header =
          case severity
          when "INFO"
            header.colorize(:light_blue)
          when "DEBUG"
            header.colorize(:magenta)
          when "WARN"
            header.colorize(:yellow)
          when "ERROR", "FATAL"
            header.colorize(:red)
          else
            header
          end

        body =
          case severity
          when "INFO", "DEBUG"
            body.colorize(:light_black)
          when "WARN"
            body.colorize(:yellow)
          when "ERROR", "FATAL"
            body.colorize(:red)
          else
            body
          end

        puts "#{header}#{body}"
      end

      "#{header}#{body}"
    end
  end

  def self.initialize_redis
    @redis = Redis.new(REDIS_OPTS)
  end

  # Borrowed from Rails, load the ENV
  # https://github.com/rails/rails/blob/master/railties/lib/rails.rb:72
  @env ||= ActiveSupport::StringInquirer.new(ENV["ESM_ENV"].presence || "development")

  # Load the config
  config = YAML.safe_load(ERB.new(File.read(File.expand_path("config/config.yml"))).result, aliases: true)[self.env]
  @config = JSON.parse(config.to_json, object_class: OpenStruct)
end

require_relative "esm/database"
ESM::Database.connect!

# Run pre_init (Throwback to Exile)
require_relative "pre_init"
require_relative "pre_init_dev" if ESM.env.development?
