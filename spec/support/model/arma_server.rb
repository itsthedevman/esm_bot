# frozen_string_literal: true

# Net::SSH.start('host', 'user') do |ssh|
# https://github.com/net-ssh/net-ssh
class ArmaServer
  CONFIG = OpenStruct.new(
    esm_arma_path: ENV["ESM_ARMA_PATH"],
    extension_version: ENV["EXTENSION_VERSION"]
  ).freeze

  def self.start!
    build_mod
    copy_mod

    # start_server
    # start_client
  end

  def self.build_mod
    command = "cd #{CONFIG.esm_arma_path} && ./bin/build --target=windows"
    command += " --use-x86" if CONFIG.extension_version == "x86"

    # Execute the command
    `#{command}`
  end

  def self.copy_mod
  end
end
