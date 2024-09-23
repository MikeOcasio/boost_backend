class AddIsPriorityToProducts < ActiveRecord::Migration[6.0]
  def change
    add_column :products, :is_priority, :boolean, default: false
  end
end
