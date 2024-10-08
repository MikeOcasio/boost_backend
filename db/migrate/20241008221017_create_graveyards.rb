class CreateGraveyards < ActiveRecord::Migration[7.0]
  def change
    create_table :graveyards do |t|

      t.timestamps
    end
  end
end
