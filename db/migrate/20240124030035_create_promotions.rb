class CreatePromotions < ActiveRecord::Migration[6.0]
  def change
    create_table :promotions do |t|
      t.string :code
      t.decimal :discount_percentage
      t.datetime :start_date
      t.datetime :end_date

      t.timestamps
    end
  end
end
