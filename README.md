<div align="center">
  <br>
  <h1>Exile Server Manager</h1>
  <strong>A multi-faceted Discord Bot for Arma 3 Exile</strong>
</div>
<br>
<p align="center">
  <a href="https://www.ruby-lang.org/en/">
    <img src="https://img.shields.io/badge/Ruby-v3.2.2-green.svg" alt="ruby version">
  </a>
  <a href="https://www.esmbot.com/">
    <img src="https://img.shields.io/badge/ESM-v2.3.0-blue.svg" alt="ruby version">
  </a>
</p>

# What is Exile Server Manager?
Exile Server Manager, or ESM for short, is a Discord Bot that facilitates interacting with an Arma 3 Exile server. Server owners and players alike can link their Steam accounts with ESM to enable running various commands to interact with their characters on any server they have joined.

## Suggestions
ESM was and still is built for the Exile community with a majority of ESM's features started out as suggestions. If you would like to make a suggestion, please join our <a href="https://esmbot.com/join">Discord</a> and post it in the #suggestions channel.

## Before continuing...
Are you a server owner or player looking to use Exile Server Manager? If so, please visit my <a href="https://www.esmbot.com/wiki">Getting Started</a> section of the Wiki as this README is focused on the development side of ESM.

## Getting Started
ESM is written in MRI Ruby 2.7.5 with DiscordRB 3.4.0 and PostgreSQL 12. I, personally, use <a href="https://rvm.io/">RVM</a> to manage Ruby, but ESM is not dependent on it.

ESM is developed using Ubuntu via [Multipass](https://multipass.run/) on Windows. The Arma server runs on the Windows and ESM runs on the linux VM. This setup allows the Arma server to be able to communicate with the bot via a local IP.

You will need to install the following to develop ESM locally:
- A Linux environment (Ubuntu recommended)
  - Ruby 2.7.1
  - Bundler
    - `gem install bundler`
  - PostgreSQL 12
  - Rust
- A Windows environment
  - Arma 3
  - Arma 3 Server with Exile mod and @esm loaded
  - Rust

## Testing


## Suggestions
ESM was and still is built for the Exile community with a majority of ESM's features started out as suggestions. If you would like to make a suggestion, please join our <a href="https://esmbot.com/join">Discord</a> and post it in the #suggestions channel.

## License
<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />Exile Server Manager work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

# Beyond here lies wips

## Setting up the bot
This guide expects that you have knowledge and experience working with the following:

- Ruby 2+
- Environment variables
- ActiveRecord and SQL
- RSpec
- Discordrb

Steps:

- Windows host
- Install Multipass
- Create VM: `multipass launch --cpus 4 --mem 8G --disk 75G --name esm`
- Install Ruby
- Install Rust
- Install Docker and Docker Compose
- Clone repo
- Start the docker images `sudo docker compose up -d`
- Configure .env
- Duplicate `spec/example.test_data.yml`, rename to `test_data.yml`, and configure the entire file
- bin/setup
