# frozen_string_literal: true

module ESM
  module Connection
    class Socket
      READ_BYTES = 65_444 - 20 - 8

      delegate_missing_to :@socket

      def initialize(socket)
        @socket = socket
      end

      def address
        @socket.local_address.inspect_sockaddr
      end

      def accept
        return unless acceptable?

        @socket.accept_nonblock
      rescue IO::EAGAINWaitReadable
      rescue => e
        error!(error: e)
      end

      def read
        return unless readable?

        @socket.recv_nonblock(READ_BYTES)
      rescue => e
        error!(error: e)
      end

      def write(data)
        raise TypeError, "Expected String, got #{data.class}" unless data.is_a?(String)

        @socket.send(data, 0)
      rescue TypeError
        raise
      rescue => e
        error!(error: e)
      end

      def close
        @socket.close_write if writeable?(0)
        @socket.close_read if readable?(0)
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
      rescue IOError
        [[], [], []]
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
      rescue IOError
        [[], [], []]
      end

      def readable?(timeout = 5)
        wait_readable(timeout).first.size > 0
      end

      # Important for rspec
      alias_method :acceptable?, :readable?

      def writeable?(timeout = 5)
        wait_writeable(timeout).second.size > 0
      end
    end
  end
end
