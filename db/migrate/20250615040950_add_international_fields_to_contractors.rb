class AddInternationalFieldsToContractors < ActiveRecord::Migration[7.0]
  def change
    add_column :contractors, :country_code, :string
    add_column :contractors, :country_name, :string
    add_column :contractors, :tax_id_type, :string
    add_column :contractors, :withholding_rate, :decimal, precision: 5, scale: 4
    add_column :contractors, :address_line1, :string
    add_column :contractors, :address_line2, :string
    add_column :contractors, :city, :string
    add_column :contractors, :state_province, :string
    add_column :contractors, :postal_code, :string
    add_column :contractors, :date_of_birth, :date

    add_index :contractors, :country_code
    add_index :contractors, :withholding_rate
  end
end
