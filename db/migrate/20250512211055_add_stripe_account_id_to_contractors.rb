class AddStripeAccountIdToContractors < ActiveRecord::Migration[7.0]
  def change
    add_column :contractors, :stripe_account_id, :string
  end
end
