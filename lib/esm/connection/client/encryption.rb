# frozen_string_literal: true

module ESM
  module Connection
    class Client
      class Encryption
        attr_reader :nonce_indices

        CIPHER = "aes-256-gcm"

        NONCE_SIZE = 12

        # First 32 bytes
        INDEX_LOW_BOUNDS = 0
        INDEX_HIGH_BOUNDS = 31

        def initialize(key)
          @key = key
          @nonce_regenerated = false
          @nonce_indices = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
          raise "Nonce size differs from default" if @nonce_indices.size != NONCE_SIZE
        end

        def regenerate_nonce_indices
          return if @nonce_regenerated

          @nonce_regenerated = true

          indices = (INDEX_LOW_BOUNDS..INDEX_HIGH_BOUNDS).to_a
          @nonce_indices = NONCE_SIZE.times.map { indices.sample }

          nil
        end

        def encrypt(data, nonce_indices: @nonce_indices)
          cipher = OpenSSL::Cipher.new(CIPHER)
          cipher.encrypt
          nonce = cipher.random_iv

          cipher.key = @key[0..31]
          cipher.iv = nonce

          nonce_bytes = nonce.bytes
          encrypted_data = cipher.update(data) + cipher.final
          encrypted_bytes = Base64.encode64(encrypted_data).bytes

          nonce_indices.each_with_index do |nonce_index, index|
            encrypted_bytes.insert(nonce_index, nonce_bytes[index])
          end

          # If the nonce index is greater than the size of the encrypted_bytes,
          # ruby will add `nil` until it gets to the index
          encrypted_bytes.compact
        end

        def decrypt(bytes, nonce_indices: @nonce_indices)
          cipher = OpenSSL::Cipher.new(CIPHER)
          cipher.decrypt

          nonce = []
          packet = []

          bytes.each_with_index do |byte, index|
            if (nonce_index = nonce_indices[nonce.size]) && (nonce_index == index)
              nonce << byte
              next
            end

            packet << byte
          end

          cipher.key = @key[0..31]
          cipher.iv = nonce.pack("C*")

          decoded_packet = Base64.decode64(packet.format(&:chr))
          cipher.update(decoded_packet)
        end
      end
    end
  end
end
