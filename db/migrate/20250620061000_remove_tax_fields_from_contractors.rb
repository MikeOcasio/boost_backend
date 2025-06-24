class RemoveTaxFieldsFromContractors < ActiveRecord::Migration[7.0]
  def up
    # Remove all tax-related fields since we're only using PayPal now
    remove_column :contractors, :tax_form_status, :string if column_exists?(:contractors, :tax_form_status)
    remove_column :contractors, :tax_form_type, :string if column_exists?(:contractors, :tax_form_type)
    remove_column :contractors, :country_code, :string if column_exists?(:contractors, :country_code)
    remove_column :contractors, :country_name, :string if column_exists?(:contractors, :country_name)
    remove_column :contractors, :tax_id_type, :string if column_exists?(:contractors, :tax_id_type)
    remove_column :contractors, :withholding_rate, :decimal if column_exists?(:contractors, :withholding_rate)

    # Remove encrypted tax fields
    remove_column :contractors, :encrypted_tax_id, :text if column_exists?(:contractors, :encrypted_tax_id)
    remove_column :contractors, :encrypted_full_legal_name, :text if column_exists?(:contractors, :encrypted_full_legal_name)
    remove_column :contractors, :encrypted_date_of_birth, :text if column_exists?(:contractors, :encrypted_date_of_birth)
    remove_column :contractors, :encrypted_address_line_1, :text if column_exists?(:contractors, :encrypted_address_line_1)
    remove_column :contractors, :encrypted_address_line_2, :text if column_exists?(:contractors, :encrypted_address_line_2)
    remove_column :contractors, :encrypted_city, :text if column_exists?(:contractors, :encrypted_city)
    remove_column :contractors, :encrypted_state_province, :text if column_exists?(:contractors, :encrypted_state_province)
    remove_column :contractors, :encrypted_postal_code, :text if column_exists?(:contractors, :encrypted_postal_code)
  end

  def down
    # Add back fields if needed for rollback
    add_column :contractors, :tax_form_status, :string, default: 'pending'
    add_column :contractors, :tax_form_type, :string
    add_column :contractors, :country_code, :string
    add_column :contractors, :country_name, :string
    add_column :contractors, :tax_id_type, :string
    add_column :contractors, :withholding_rate, :decimal, precision: 5, scale: 4

    # Add back encrypted fields
    add_column :contractors, :encrypted_tax_id, :text
    add_column :contractors, :encrypted_full_legal_name, :text
    add_column :contractors, :encrypted_date_of_birth, :text
    add_column :contractors, :encrypted_address_line_1, :text
    add_column :contractors, :encrypted_address_line_2, :text
    add_column :contractors, :encrypted_city, :text
    add_column :contractors, :encrypted_state_province, :text
    add_column :contractors, :encrypted_postal_code, :text
  end
end
