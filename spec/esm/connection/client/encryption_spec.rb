# frozen_string_literal: true

describe ESM::Connection::Client::Encryption do
  let(:different_encryption) { described_class.new("This is a complete different key not the same at all") }

  subject!(:encryption) { described_class.new("This is the super secret key that is used to encrypt") }

  describe "#encrypt" do
    context "when text is provided" do
      it "returns the encrypted text as a Base64 encoded string" do
        encrypted_text = encryption.encrypt("Hello world!")

        # I can't know what the text will be due to the nonce
        # But I can check if it was encoded correctly
        expect { Base64.strict_decode64(encrypted_text) }.not_to raise_error

        # And technically check if it decrypts
        expect { encryption.decrypt(encrypted_text) }.not_to raise_error

        # It should also fail decryption with another key
        expect {
          different_encryption.decrypt(encrypted_text)
        }.to raise_error(ESM::Connection::Client::DecryptionError)
      end
    end
  end

  describe "#decrypt" do
    context "when the provided text fails Base64 decode" do
      it "raises an exception" do
        expect { encryption.decrypt("z") }.to raise_error(ESM::Connection::Client::InvalidBase64)
      end
    end

    context "when the provided text does not include the correct nonce" do
      it "raises an exception" do
        encrypted_text = encryption.encrypt("Hello world")

        expect {
          encryption.decrypt(
            encrypted_text,
            # The nonce is 0...size, this is off by 1
            nonce_indices: (1...described_class::NONCE_SIZE).to_a
          )
        }.to raise_error(ESM::Connection::Client::InvalidNonce)
      end
    end

    context "when the provided text was not encrypted with the same key" do
      it "raises an exception" do
        encrypted_text = encryption.encrypt("Hello world")

        expect {
          different_encryption.decrypt(encrypted_text)
        }.to raise_error(ESM::Connection::Client::DecryptionError)
      end
    end

    context "when the provided text was encrypted and encoded correctly" do
      it "returns the decoded and decrypted text" do
        encrypted_text = encryption.encrypt("Hello world")
        decrypted_text = encryption.decrypt(encrypted_text)
        expect(decrypted_text).to eq("Hello world")
      end
    end
  end
end
