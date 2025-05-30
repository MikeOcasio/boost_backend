class AddBalanceFieldsToContractors < ActiveRecord::Migration[7.0]
  def change
    add_column :contractors, :available_balance, :decimal, default: 0.0, precision: 10, scale: 2
    add_column :contractors, :pending_balance, :decimal, default: 0.0, precision: 10, scale: 2
    add_column :contractors, :total_earned, :decimal, default: 0.0, precision: 10, scale: 2
    add_column :contractors, :last_withdrawal_at, :datetime
  end
end
