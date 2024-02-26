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
          key = key.bytes[INDEX_LOW_BOUNDS..INDEX_HIGH_BOUNDS]
          raise ArgumentError, "Encryption key must be 32 bytes" if key.size != 32

          @key = key.pack("C*")
          @nonce_regenerated = false
          @nonce_indices = (0...NONCE_SIZE).to_a
        end

        def regenerate_nonce_indices
          return if @nonce_regenerated

          @nonce_regenerated = true

          indices = (INDEX_LOW_BOUNDS...INDEX_HIGH_BOUNDS).to_a.shuffle.shuffle
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
          Base64.strict_encode64(encrypted_data.compact.pack("C*"))
        end

        #
        # Attempts to decrypt the provided byte array
        #
        # @param input [String] A Base64 encoded UTF-8 string containing encrypted data
        # @param nonce_indices [<Type>] The nonce location as an index in the Base64 DEcoded byte array
        #
        # @return [String] The decoded string
        #
        # @raises DecryptionError
        # @raises InvalidBase64
        # @raises InvalidSecretKey
        # @raises InvalidNonce
        #
        def decrypt(input, nonce_indices: @nonce_indices)
          cipher = OpenSSL::Cipher.new(CIPHER).decrypt

          encoded_packet = Base64.strict_decode64(input).bytes

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

          decrypted_data = cipher.update(packet.pack("C*")) + cipher.final
          raise DecryptionError if decrypted_data.blank?

          decrypted_data
        rescue ArgumentError => e
          case e.message
          when "invalid base64"
            raise InvalidBase64
          when "key must be 32 bytes"
            raise InvalidSecretKey
          when "iv must be #{NONCE_SIZE} bytes"
            raise InvalidNonce
          else
            raise e
          end
        rescue OpenSSL::Cipher::CipherError
          raise DecryptionError
        end
      end
    end
  end
end
