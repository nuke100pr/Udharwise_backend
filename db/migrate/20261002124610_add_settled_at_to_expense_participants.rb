class AddSettledAtToExpenseParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :expense_participants, :settled_at, :datetime
  end
end
