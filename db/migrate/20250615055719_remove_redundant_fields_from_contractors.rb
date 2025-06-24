class RemoveRedundantFieldsFromContractors < ActiveRecord::Migration[7.0]
  def change
    # Remove redundant unencrypted address fields (we now have encrypted versions)
    remove_column :contractors, :address_line1, :string
    remove_column :contractors, :address_line2, :string
    remove_column :contractors, :city, :string
    remove_column :contractors, :state_province, :string
    remove_column :contractors, :postal_code, :string

    # Remove tax_id_type as we can derive this from country_info
    remove_column :contractors, :tax_id_type, :string
  end
end
