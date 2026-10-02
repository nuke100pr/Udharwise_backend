class CreateGroupInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :group_invites do |t|
      t.references :group, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: {to_table: :users}
      t.references :invitee, null: false, foreign_key: {to_table: :users}
      t.string :status , null: false, default: "pending"

      t.timestamps
    end

    add_index :group_invites, [:group_id, :invitee_id]
  end
end
