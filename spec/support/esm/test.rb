# frozen_string_literal: true

module ESM
  class Test
    # Don't forget to add new entries to .reset!
    class << self
      attr_reader :response
      attr_writer :messages
      attr_accessor :skip_cooldown, :block_outbound_messages

      def messages
        @messages ||= Messages.new
      end

      def outbound_server_messages
        @outbound_server_messages ||= Messages.new
      end

      def inbound_server_messages
        @inbound_server_messages ||= Messages.new
      end

      def data
        @data ||= lambda do
          data = YAML.load_file(File.expand_path("./spec/test_data.yml")).deep_symbolize_keys
          redis.set("test_data", data.to_json)

          data
        end.call
      end

      # Attempt to simulate a random community for tests
      #
      # @note The type of community controls what user type is selected
      # @see #reset!
      def community(type: @community_type)
        @community ||= FactoryBot.create(type, :player_mode_disabled)
      end

      def second_community
        @second_community ||= FactoryBot.create(@second_community_type, :player_mode_disabled)
      end

      # Attempt to simulate random users for tests
      #
      # @note The type of community controls what user type is selected
      # @see #reset!
      def user(*args, type: @user_type)
        args = [type] + args
        @user ||= FactoryBot.create(*args)
      end

      # Creates a second user that isn't #user
      def second_user
        @second_user ||= FactoryBot.create(@user_type, not_user: user)
      end

      def server
        @server ||= FactoryBot.create(:server, community_id: community.id)
      end

      def second_server
        @second_server ||= FactoryBot.create(:server, community_id: second_community.id)
      end

      def channel
        @channel ||= lambda do
          id = data[community.guild_type][:channels].sample
          ESM.bot.channel(id)
        end.call
      end

      def redis
        @redis ||= Redis.new(ESM::REDIS_OPTS)
      end

      def response=(value)
        @response = {
          message: {
            content: value
          }
        }.to_ostruct
      end

      def reset!
        @response = nil
        @messages = nil
        @outbound_server_messages = nil
        @inbound_server_messages = nil
        @community = nil
        @server = nil
        @user = nil
        @second_user = nil
        @channel = nil

        @skip_cooldown = false
        @block_outbound_messages = false

        @communities = %i[primary_community secondary_community]
        @community_type = @communities.sample
        @user_type = @community_type == :primary_community ? :primary_user : :secondary_user
        @second_community_type = @communities.find { |type| type != @community_type }

        # Reset the bot's resend_queue
        ESM.bot.resend_queue.reset

        # Auto resume in case if was paused
        ESM.bot.resend_queue.resume

        # Clear the test list in Redis
        redis.del("test")
      end

      # I hate this code, it doesn't make me happy
      def await(timeout: nil)
        timeout ||= 5

        # Offset the fact that we check every 0.25s
        timeout *= 4
        counter = 0

        sleep(0.25)
        while self.response.blank? && counter < timeout
          sleep(0.25)
          counter += 1
        end

        response
      end

      def await_and_reply(message, wait: 1)
        Thread.new do
          sleep(wait)
          self.response = message
        end
      end

      def wait_until(timeout: 30, &block)
        # Offset the fact that we check every 0.25s
        timeout *= 4
        counter = 0

        while counter < timeout
          sleep(0.25)
          counter += 1

          # I don't have this in the conditional above because I want it to sleep at least once
          return if yield == true
        end

        raise StandardError, "Timeout!"
      end
    end
  end
end
