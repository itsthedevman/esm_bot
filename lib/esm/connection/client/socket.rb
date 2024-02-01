# frozen_string_literal: true

module ESM
  module Connection
    class Client
      class Socket
        READ_BYTES = 65_444

        delegate :close, :puts, :gets, to: :@socket

        def initialize(socket)
          @socket = socket
        end

        def read
          return unless readable?

          loop do
            buffer = @socket.recv_nonblock(READ_BYTES)
            binding.pry
          end
        end

        #
        # Blocks until the socket is readable
        #
        # @param timeout [Integer] Timeout in seconds
        #
        # @returns [Array] The sockets grouped by state [readable, writeable, errored]
        #
        def wait_readable(timeout = 5)
          IO.select([@socket], nil, nil, timeout) || [[], [], []]
        end

        #
        # Blocks until the socket is writeable
        #
        # @param timeout [Integer] Timeout in seconds
        #
        # @returns [Array] The sockets grouped by state [readable, writeable, errored]
        #
        def wait_writeable(timeout = 5)
          IO.select(nil, [@socket], nil, timeout) || [[], [], []]
        end

        def readable?
          wait_readable.first.size > 0
        end

        def writeable?
          wait_writeable.second.size > 0
        end
      end
    end
  end
end
