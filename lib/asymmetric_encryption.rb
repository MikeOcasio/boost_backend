# app/lib/asymmetric_encryption.rb

require 'openssl'

class AsymmetricEncryption
  def self.generate_key_pair
    key = OpenSSL::PKey::RSA.new(2048) # 2048 bits for key size, adjust as needed
    public_key = key.public_key.to_s
    private_key = key.to_s
    { public_key: public_key, private_key: private_key }
  end

  def self.encrypt(data, public_key)
    cipher = OpenSSL::PKey::RSA.new(public_key)
    encrypted_data = cipher.public_encrypt(data)
    Base64.strict_encode64(encrypted_data)
  end

  def self.decrypt(encrypted_data, private_key)
    cipher = OpenSSL::PKey::RSA.new(private_key)
    decrypted_data = cipher.private_decrypt(Base64.strict_decode64(encrypted_data))
    decrypted_data.force_encoding('utf-8')
  end
end
