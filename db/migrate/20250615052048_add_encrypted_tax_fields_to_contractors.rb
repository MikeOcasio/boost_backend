class AddEncryptedTaxFieldsToContractors < ActiveRecord::Migration[7.0]
  def change
    # Add encrypted fields for sensitive tax information
    add_column :contractors, :encrypted_tax_id, :text
    add_column :contractors, :encrypted_full_legal_name, :text
    add_column :contractors, :encrypted_date_of_birth, :text
    add_column :contractors, :encrypted_address_line_1, :text
    add_column :contractors, :encrypted_address_line_2, :text
    add_column :contractors, :encrypted_city, :text
    add_column :contractors, :encrypted_state_province, :text
    add_column :contractors, :encrypted_postal_code, :text

    # Remove old unencrypted fields if they exist (we'll handle data migration separately)
    # Note: In production, you'd want to migrate data first, then drop columns
    if column_exists?(:contractors, :tax_id)
      remove_column :contractors, :tax_id, :string
    end
    if column_exists?(:contractors, :full_legal_name)
      remove_column :contractors, :full_legal_name, :string
    end
    if column_exists?(:contractors, :date_of_birth)
      remove_column :contractors, :date_of_birth, :date
    end
  end
end
