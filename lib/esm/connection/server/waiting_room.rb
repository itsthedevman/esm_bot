# frozen_string_literal: true

module ESM
  module Connection
    class Server
      # I would like to use Concurrent::Array but it's not thread safe
      # https://github.com/ruby-concurrency/concurrent-ruby/issues/929
      class WaitingRoom
        Entry = ImmutableStruct.define(:connected_at, :client)

        def initialize
          @lock = Mutex.new
          @inner = []
        end

        def shutdown
          @lock.synchronize do
            @inner.each(&:close)
            @inner = []
          end
        end

        def include?(client)
          @lock.synchronize { @inner.include?(client) }
        end

        def <<(client)
          @lock.synchronize do
            @inner << Entry.new(
              connected_at: Time.current,
              client: client
            )
          end
        end

        def delete(client)
          @lock.synchronize { @inner.delete(client) }
        end

        def delete_if(&block)
          @lock.synchronize { @inner.delete_if(&block) }
        end

        def size
          @lock.synchronize { @inner.size }
        end
      end
    end
  end
end
