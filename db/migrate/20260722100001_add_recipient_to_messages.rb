class AddRecipientToMessages < ActiveRecord::Migration[8.1]
  def change
    add_reference :messages, :recipient, foreign_key: { to_table: :users }
  end
end
