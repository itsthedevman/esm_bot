# frozen_string_literal: true

module ESM
  module Command
    module Test
      class TextChannelCommand < TestCommand
        limit_to :text

        def on_execute
        end

        def on_response(_, _)
        end
      end
    end
  end
end
