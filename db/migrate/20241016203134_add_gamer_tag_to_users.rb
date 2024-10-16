class AddGamerTagToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :gamer_tag, :string
  end
end
