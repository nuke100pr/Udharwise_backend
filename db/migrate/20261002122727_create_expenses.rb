class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :group, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: {to_table: :users}
      t.string :description
      t.integer :total_paise , null: false
      t.datetime :archived_at

      t.timestamps
    end
  end
end
