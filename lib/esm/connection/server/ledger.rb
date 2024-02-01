# frozen_string_literal: true

module ESM
  module Connection
    class Server
      class Ledger < Concurrent::Map
        class Entry < ImmutableStruct.define(:request, :mailbox)
          def initialize(mailbox: nil, **)
            super(mailbox: Concurrent::MVar.new, **)
          end
        end

        def add(request)
          entry = Entry.new(request: request)
          self[request.id] = entry

          entry.mailbox
        end

        def remove(request)
          delete(request.id)
        end
      end
    end
  end
end
