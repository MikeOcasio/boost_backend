class AddCountryAndRegionToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :country, :string
    add_column :users, :region, :string
    add_column :users, :currency, :string, default: 'USD'

    # Add indexes for better performance
    add_index :users, :country
    add_index :users, :currency
  end
end
