class AddBookingOverlapExclusionConstraint < ActiveRecord::Migration[8.1]
  def change
    enable_extension "btree_gist"

    reversible do |dir|
      dir.up do
        execute <<-SQL
          ALTER TABLE bookings
          ADD CONSTRAINT bookings_no_overlapping_ranges
          EXCLUDE USING gist (
            rv_listing_id WITH =,
            daterange(start_date, end_date, '[)') WITH &&
          )
          WHERE (status IN ('pending', 'confirmed'))
        SQL
      end

      dir.down do
        execute "ALTER TABLE bookings DROP CONSTRAINT bookings_no_overlapping_ranges"
      end
    end
  end
end
