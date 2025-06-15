# app/lib/symmetric_encryption.rb

require 'rbnacl/libsodium'

class SymmetricEncryption
  def self.generate_key
    RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes)
  end

  def self.encrypt(data, key)
    # Convert string key to binary if needed
    binary_key = key.is_a?(String) ? key.force_encoding('BINARY') : key
    # Ensure key is exactly 32 bytes
    binary_key = binary_key[0, 32].ljust(32, "\x00") if binary_key.length != 32

    cipher = RbNaCl::SecretBox.new(binary_key)
    nonce = RbNaCl::Random.random_bytes(cipher.nonce_bytes)

    encrypted_data = cipher.encrypt(nonce, data.to_s.force_encoding('BINARY'))

    Base64.strict_encode64(nonce + encrypted_data)
  end

  def self.decrypt(encrypted_data, key)
    # Convert string key to binary if needed
    binary_key = key.is_a?(String) ? key.force_encoding('BINARY') : key
    # Ensure key is exactly 32 bytes
    binary_key = binary_key[0, 32].ljust(32, "\x00") if binary_key.length != 32

    cipher = RbNaCl::SecretBox.new(binary_key)

    decoded_data = Base64.strict_decode64(encrypted_data)
    nonce = decoded_data[0...cipher.nonce_bytes]
    ciphertext = decoded_data[cipher.nonce_bytes..-1]

    cipher.decrypt(nonce, ciphertext).force_encoding('UTF-8')
  end
end
