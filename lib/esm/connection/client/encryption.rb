# frozen_string_literal: true

module ESM
  module Connection
    class Client
      class Encryption
        attr_reader :nonce_indices

        CIPHER = "aes-256-cbc"

        NONCE_SIZE = 16

        # First 32 bytes
        INDEX_LOW_BOUNDS = 0
        INDEX_HIGH_BOUNDS = 31

        def initialize(key)
          @key = key.bytes[0..31].pack("C*")
          @nonce_regenerated = false
          @nonce_indices = (0...NONCE_SIZE).map { |i| i }
        end

        def regenerate_nonce_indices
          return if @nonce_regenerated

          @nonce_regenerated = true

          indices = (INDEX_LOW_BOUNDS..INDEX_HIGH_BOUNDS).to_a.shuffle.shuffle
          @nonce_indices = NONCE_SIZE.times.map { indices.pop }.sort

          nil
        end

        def encrypt(data, nonce_indices: @nonce_indices)
          cipher = OpenSSL::Cipher.new(CIPHER).encrypt
          nonce = cipher.random_iv

          cipher.key = @key
          cipher.iv = nonce

          nonce_bytes = nonce.bytes
          encrypted_data = (cipher.update(data) + cipher.final).bytes

          nonce_indices.each_with_index do |nonce_index, index|
            encrypted_data.insert(nonce_index, nonce_bytes[index])
          end

          # If the nonce index is greater than the size of the encrypted_bytes,
          # ruby will add `nil` until it gets to the index
          Base64.strict_encode64(encrypted_data.compact.pack("C*")).bytes
        end

        def decrypt(bytes, nonce_indices: @nonce_indices)
          cipher = OpenSSL::Cipher.new(CIPHER).decrypt
          encoded_packet = Base64.strict_decode64(bytes.pack("U*")).bytes

          nonce = []
          packet = []

          encoded_packet.each_with_index do |byte, index|
            if nonce_indices[nonce.size] == index
              nonce << byte
              next
            end

            packet << byte
          end

          cipher.key = @key
          cipher.iv = nonce.pack("C*")

          cipher.update(packet.pack("C*")) + cipher.final
        end
      end
    end
  end
end
