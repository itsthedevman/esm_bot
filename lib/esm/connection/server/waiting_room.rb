# frozen_string_literal: true

module ESM
  module Connection
    class Server
      class WaitingRoom < Concurrent::Array
        Entry = ImmutableStruct.define(:connected_at, :client)

        def shutdown
          each { |e| e.client.close("shutdown") }
        end

        def include?(client)
          any? { |e| e.client == client }
        end

        def <<(client)
          super(Entry.new(
            connected_at: Time.current,
            client: client
          ))
        end

        def delete(client)
          delete_if { |e| e.client == client }
        end
      end
    end
  end
end
