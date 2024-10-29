class AddSliderToProduct < ActiveRecord::Migration[7.0]
  def change
    change_table :products, bulk: true do |t|
      t.boolean :is_slider, default: false
      t.jsonb :slider_range, default: []
    end
  end
end
