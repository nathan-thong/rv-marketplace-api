class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.date :start_date
      t.date :end_date
      t.string :status, default: "pending", null: false
      t.references :user, null: false, foreign_key: true
      t.references :rv_listing, null: false, foreign_key: true

      t.timestamps
    end
  end
end
