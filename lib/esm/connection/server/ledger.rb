# frozen_string_literal: true

module ESM
  module Connection
    class Server
      class Ledger < Concurrent::Map
        def include?(request)
          !self[request.id].nil?
        end

        def add(request)
          self[request.id] = Concurrent::MVar.new
        end

        def remove(request)
          delete(request.id)
        end
      end
    end
  end
end
