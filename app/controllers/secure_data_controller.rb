# app/controllers/secure_data_controller.rb

class SecureDataController < ApplicationController
  def index
    # Step 1: Generate symmetric key
    symmetric_key = SymmetricEncryption.generate_key

    # Step 2: Generate asymmetric key pair for key exchange
    AsymmetricEncryption.generate_key_pair

    # Step 3: Encrypt data using symmetric key
    plaintext_data = 'Sensitive information'
    SymmetricEncryption.encrypt(plaintext_data, symmetric_key)

    # Step 4: Encrypt symmetric key using recipient's public key
    recipient_public_key = 'recipient_public_key' # Replace with the actual public key received from the recipient
    AsymmetricEncryption.encrypt(symmetric_key, recipient_public_key)

    # In a real-world scenario, you might store or transmit the encrypted_data and encrypted_symmetric_key as needed.
  end

  # app/controllers/secure_data_controller.rb

  def generate_symmetric_key
    symmetric_key = SymmetricEncryption.generate_key
    render json: { symmetric_key: symmetric_key }
  end

  def generate_asymmetric_key_pair
    key_pair = AsymmetricEncryption.generate_key_pair
    render json: { public_key: key_pair[:public_key], private_key: key_pair[:private_key] }
  end

  def encrypt_data
    # Extract data and symmetric key from request params
    plaintext_data = params[:data]
    symmetric_key = params[:symmetric_key]

    # Encrypt data using symmetric key
    encrypted_data = SymmetricEncryption.encrypt(plaintext_data, symmetric_key)

    render json: { encrypted_data: encrypted_data }
  end

  def encrypt_symmetric_key
    # Extract symmetric key and public key from request params
    symmetric_key = params[:symmetric_key]
    public_key = params[:public_key]

    # Encrypt symmetric key using recipient's public key
    encrypted_symmetric_key = AsymmetricEncryption.encrypt(symmetric_key, public_key)

    render json: { encrypted_symmetric_key: encrypted_symmetric_key }
  end
end
