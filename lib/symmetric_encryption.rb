# app/lib/symmetric_encryption.rb

require 'rbnacl/libsodium'

class SymmetricEncryption
  def self.generate_key
    RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
  end

  def self.encrypt(data, key)
    cipher = RbNaCl::SecretBox.new(key)
    nonce = RbNaCl::Random.random_bytes(cipher.nonce_bytes)

    encrypted_data = cipher.encrypt(nonce, data)

    Base64.strict_encode64(nonce + encrypted_data)
  end

  def self.decrypt(encrypted_data, key)
    cipher = RbNaCl::SecretBox.new(key)

    decoded_data = Base64.strict_decode64(encrypted_data)
    nonce = decoded_data[0...cipher.nonce_bytes]
    ciphertext = decoded_data[cipher.nonce_bytes..-1]

    cipher.decrypt(nonce, ciphertext)
  end
end
