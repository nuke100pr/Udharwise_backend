class CreateExpenseParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :expense_participants do |t|
      t.references :expense, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :share_paise, null: false, default: 0
      t.integer :paid_paise, null: false, default: 0
      t.timestamps
    end

    add_index :expense_participants, [:expense_id, :user_id], unique: true
  end
end
