class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :phone
      t.string :handle

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :phone, unique: true  
    add_index :users, :handle, unique: true
    
  end
end
