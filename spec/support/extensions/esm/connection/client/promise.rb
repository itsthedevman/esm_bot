# frozen_string_literal: true

module ESM
  module Connection
    class Client
      class Promise
        def reset_promise
          @promise = Concurrent::Promise.new
          self
        end
      end
    end
  end
end
