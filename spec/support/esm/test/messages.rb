# frozen_string_literal: true

module ESM
  class Test
    class Messages < Array
      class Message
        attr_reader :destination, :content

        def initialize(destination, content)
          @destination = destination
          @content = content
        end

        # Legacy support
        def first
          @destination
        end

        def second
          @content
        end
      end

      def store(content, channel)
        self << Message.new(channel, content)

        # Don't break tests
        content
      end

      def find(needle)
        super do |message|
          content = message.content
          if content.is_a?(ESM::Embed)
            content.title&.match?(needle) || content.description&.match?(needle)
          else
            content&.match?(needle)
          end
        end
      end
    end
  end
end
