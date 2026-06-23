class CreateRvListings < ActiveRecord::Migration[8.1]
  def change
    create_table :rv_listings do |t|
      t.string :title, null: false
      t.text :description, null: false
      t.string :location, null: false
      t.decimal :price_per_day, null: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
