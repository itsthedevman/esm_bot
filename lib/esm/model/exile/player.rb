# frozen_string_literal: true

module ESM
  module Exile
    class Player
      def initialize(server:, player_data:)
        @server = server
        @data = player_data
        @alive = false

        # If the player is dead, not all information is returned.
        normalize
      end

      def name
        @data.name
      end

      def alive?
        @alive
      end

      # Arma stores the health as 0 (full) to 1 (dead)
      def damage
        (100 - (@data.damage * 100)).round(2)
      end

      def hunger
        @data.hunger.round(2)
      end

      def thirst
        @data.thirst.round(2)
      end

      def money
        @data.money
      end

      def locker
        @data.locker
      end

      def respect
        @data.score
      end

      def kills
        @data.kills
      end

      def deaths
        @data.deaths
      end

      def kd_ratio
        return 0 if deaths.zero?

        # These are returns as integers, cast to float
        (kills.to_f / deaths).round(2)
      end

      def territories
        @territories ||= begin
          territories = @data.territories
          territories = territories.to_a if territories.is_a?(String)
          territories
        end
      end

      def to_embed
        ESM::Embed.build do |e|
          e.title = I18n.t("commands.me.embed.title", server_id: @server.server_id, user: name)

          add_general_field(e)
          add_currency_field(e)
          add_scoreboard_field(e)
          add_territories_field(e) if !territories.blank?
        end
      end

      private

      # Alive players return all of these fields.
      # Dead players return: locker, score, name, kills, deaths, territories
      def normalize
        @alive = false if @data.damage.nil?
        @data.damage ||= 1
        @data.hunger ||= 0
        @data.thirst ||= 0
        @data.kills ||= 0
        @data.deaths ||= 0
        @data.money ||= 0
        @data.territories ||= []
      end

      def add_general_field(embed)
        if alive?
          embed.add_field(
            name: "__#{I18n.t(:general)}__",
            value: [
              "**#{I18n.t(:health)}:**\n#{damage}%\n",
              "**#{I18n.t(:hunger)}:**\n#{hunger}%\n",
              "**#{I18n.t(:thirst)}:**\n#{thirst}%\n"
            ].join("\n"),
            inline: true
          )
        else
          embed.add_field(
            name: "__#{I18n.t(:general)}__",
            value: I18n.t(:you_are_dead),
            inline: true
          )
        end
      end

      def add_currency_field(embed)
        embed.add_field(
          name: "__#{I18n.t(:currency)}__",
          value: [
            "**#{I18n.t(:money)}:**\n#{money.to_poptab}\n",
            "**#{I18n.t(:locker)}:**\n#{locker.to_poptab}\n",
            "**#{I18n.t(:respect)}:**\n#{respect.to_readable}\n"
          ].join("\n"),
          inline: true
        )
      end

      def add_scoreboard_field(embed)
        embed.add_field(
          name: "__#{I18n.t(:scoreboard)}__",
          value: [
            "**#{I18n.t(:kills)}:**\n#{kills.to_readable}\n",
            "**#{I18n.t(:deaths)}:**\n#{deaths.to_readable}\n",
            "**#{I18n.t(:kd_ratio)}:**\n#{kd_ratio}\n"
          ].join("\n"),
          inline: true
        )
      end

      def add_territories_field(embed)
        converter =
          if @server.v2?
            ->(territory) { "**#{territory.name}**: `#{territory.id}`" }
          else
            ->(name, id) { "**#{name}**: `#{id}`" }
          end

        embed.add_field(
          name: I18n.t("territories"),
          value: territories.format(join_with: "\n", &converter)
        )
      end
    end
  end
end
